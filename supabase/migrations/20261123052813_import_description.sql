-- Imports carry a description: the file's own introduction, or a short
-- one the model wrote when the file has none (`description` in the reviewed
-- payload, see supabase/functions/ai/ai_import/prompt.ts).
--
-- A program saves it as its description, ahead of any content that couldn't
-- be placed (which used to be the whole description). A workout has no
-- description column, so it becomes the first paragraph of the workout's
-- notes. Results stored before this have no `description` and save as before.
--
-- Both functions are redefined from their newest definitions in
-- 20261122042254_program_day_sessions.sql; only the description handling
-- changed. Signatures and grants are unchanged.

create or replace function public.ai_import_create_workout(
  p_reviewed jsonb,
  p_today date
) returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_weeks jsonb := coalesce(p_reviewed -> 'weeks', '[]'::jsonb);
  v_day jsonb := coalesce(v_weeks -> 0 -> 'days' -> 0, '{}'::jsonb);
  v_placed jsonb := public.ai_import_place_notes(p_reviewed);
  v_workout_id uuid;
  v_exercise jsonb;
  v_index integer;
  v_workout_exercise_id uuid;
begin
  -- Building only the first day would silently drop the others.
  if jsonb_array_length(v_weeks) > 1
    or jsonb_array_length(coalesce(v_weeks -> 0 -> 'days', '[]'::jsonb)) > 1 then
    raise exception 'invalid_input: a workout has exactly one day' using errcode = 'P0001';
  end if;

  insert into public.workouts (
    user_id, title, date, notes, is_public, is_copy, is_imported
  ) values (
    v_user_id,
    coalesce(
      nullif(trim(p_reviewed ->> 'title'), ''),
      nullif(trim(v_day ->> 'title'), ''),
      'Imported workout'
    ),
    p_today,
    -- The import's description leads, as its own paragraph.
    nullif(concat_ws(
      E'\n\n',
      nullif(trim(p_reviewed ->> 'description'), ''),
      nullif(concat_ws(
        E'\n', nullif(trim(v_day ->> 'notes'), ''), v_placed ->> '0.0', v_placed ->> '0', v_placed ->> ''
      ), '')
    ), ''),
    false, true, true
  )
  returning id into v_workout_id;

  for v_exercise, v_index in
    select e.value, (e.n - 1)::integer
    from jsonb_array_elements(public.ai_import_day_exercises(v_day))
      with ordinality e(value, n)
    order by e.n
  loop
    insert into public.workout_exercises (workout_id, user_id, exercise_id, position, notes)
    values (
      v_workout_id,
      v_user_id,
      public.ai_import_resolve_exercise(v_exercise ->> 'name', v_exercise -> 'match'),
      v_index,
      nullif(concat_ws(
        E'\n', nullif(trim(v_exercise ->> 'notes'), ''), v_placed ->> ('0.0.' || v_index)
      ), '')
    )
    returning id into v_workout_exercise_id;

    insert into public.workout_sets (
      workout_exercise_id, user_id, position, target_reps, target_reps_max,
      weight_mode, percentage, percentage_max, absolute_weight_kg,
      rpe_min, rpe_max, basis_exercise_id, note
    )
    select
      v_workout_exercise_id, v_user_id, s.set_position, s.target_reps, s.target_reps_max,
      s.weight_mode, s.percentage, s.percentage_max, s.absolute_weight_kg,
      s.rpe_min, s.rpe_max, s.basis_exercise_id, s.note
    from public.ai_import_exercise_sets(v_exercise) s;
  end loop;

  return v_workout_id;
end;
$$;


create or replace function public.ai_import_create_program(p_reviewed jsonb)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_placed jsonb := public.ai_import_place_notes(p_reviewed);
  v_program_id uuid;
  v_week jsonb;
  v_week_index integer;
  v_program_week_id uuid;
  v_day jsonb;
  v_day_index integer;
  v_position integer := 0;
  v_program_day_id uuid;
  v_has_exercises boolean;
  v_session jsonb;
  v_session_index integer;
  v_program_session_id uuid;
  v_exercise jsonb;
  v_exercise_index integer;
  v_flat_index integer;
  v_program_exercise_id uuid;
begin
  insert into public.programs (
    user_id, name, description, is_public, is_copy, is_imported
  ) values (
    v_user_id,
    coalesce(nullif(trim(p_reviewed ->> 'title'), ''), 'Imported program'),
    -- The import's description, then any content that couldn't be placed
    -- on a week, day or exercise, which was the whole description before.
    nullif(concat_ws(E'\n\n', nullif(trim(p_reviewed ->> 'description'), ''), v_placed ->> ''), ''),
    false, true, true
  )
  returning id into v_program_id;

  for v_week, v_week_index in
    select w.value, (w.n - 1)::integer
    from jsonb_array_elements(coalesce(p_reviewed -> 'weeks', '[]'::jsonb))
      with ordinality w(value, n)
    order by w.n
  loop
    insert into public.program_weeks (
      program_id, user_id, week_number, label, notes, position
    ) values (
      v_program_id,
      v_user_id,
      v_week_index + 1,
      nullif(trim(v_week ->> 'label'), ''),
      v_placed ->> v_week_index::text,
      v_week_index
    )
    returning id into v_program_week_id;

    for v_day, v_day_index in
      select d.value, (d.n - 1)::integer
      from jsonb_array_elements(coalesce(v_week -> 'days', '[]'::jsonb))
        with ordinality d(value, n)
      order by d.n
    loop
      v_has_exercises := jsonb_array_length(public.ai_import_day_exercises(v_day)) > 0;

      insert into public.program_days (
        program_id, program_week_id, user_id, day_number, title, is_rest_day, notes, position
      ) values (
        v_program_id,
        v_program_week_id,
        v_user_id,
        v_day_index + 1,
        coalesce(
          nullif(trim(v_day ->> 'title'), ''),
          initcap(nullif(trim(v_day ->> 'weekday'), '')),
          case when (v_day ->> 'isRestDay')::boolean then 'Rest day'
               else 'Day ' || (v_day_index + 1) end
        ),
        -- start_program skips a rest day's exercises, so this can't be set on
        -- a day that has any.
        coalesce((v_day ->> 'isRestDay')::boolean, false) and not v_has_exercises,
        nullif(concat_ws(
          E'\n',
          nullif(trim(v_day ->> 'notes'), ''),
          v_placed ->> (v_week_index || '.' || v_day_index)
        ), ''),
        v_position
      )
      returning id into v_program_day_id;
      v_position := v_position + 1;
      v_flat_index := 0;

      for v_session, v_session_index in
        select s.value, (s.n - 1)::integer
        from jsonb_array_elements(public.ai_import_day_sessions(v_day)) with ordinality s(value, n)
        order by s.n
      loop
        insert into public.program_sessions (program_day_id, user_id, title, notes, position)
        values (
          v_program_day_id,
          v_user_id,
          nullif(trim(v_session ->> 'title'), ''),
          nullif(trim(v_session ->> 'notes'), ''),
          v_session_index
        )
        returning id into v_program_session_id;

        for v_exercise, v_exercise_index in
          select e.value, (e.n - 1)::integer
          from jsonb_array_elements(coalesce(v_session -> 'exercises', '[]'::jsonb))
            with ordinality e(value, n)
          order by e.n
        loop
          insert into public.program_exercises (
            program_day_id, program_session_id, user_id, exercise_id, position, notes
          ) values (
            v_program_day_id,
            v_program_session_id,
            v_user_id,
            public.ai_import_resolve_exercise(v_exercise ->> 'name', v_exercise -> 'match'),
            v_exercise_index,
            nullif(concat_ws(
              E'\n',
              nullif(trim(v_exercise ->> 'notes'), ''),
              v_placed ->> (v_week_index || '.' || v_day_index || '.' || v_flat_index)
            ), '')
          )
          returning id into v_program_exercise_id;
          v_flat_index := v_flat_index + 1;

          insert into public.program_sets (
            program_exercise_id, user_id, position, target_reps, target_reps_max,
            weight_mode, percentage, percentage_max, absolute_weight_kg,
            rpe_min, rpe_max, basis_exercise_id, note
          )
          select
            v_program_exercise_id, v_user_id, s.set_position, s.target_reps, s.target_reps_max,
            s.weight_mode, s.percentage, s.percentage_max, s.absolute_weight_kg,
            s.rpe_min, s.rpe_max, s.basis_exercise_id, s.note
          from public.ai_import_exercise_sets(v_exercise) s;
        end loop;
      end loop;
    end loop;
  end loop;

  return v_program_id;
end;
$$;

