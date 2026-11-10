-- Saves a reviewed AI import as a workout or program (#83, part of #79).
-- Additive: nothing calls ai_import_accept until the review screen ships, and
-- the one replaced function, start_program, only gains the is_imported and
-- day-notes carry-over.
--
-- p_reviewed is the ai_import_results payload after the user's review, with
-- one difference: each absolute load is sent as weightKg, converted on the
-- client by weight_converter.dart. A set still carrying the raw weight/unit
-- has no weightKg, so the workout_sets constraint refuses it rather than
-- saving a number in the wrong unit.
--
-- Everything here is SECURITY INVOKER, so each insert passes the same RLS a
-- client insert would. Only claiming the job and marking it accepted go through
-- the SECURITY DEFINER helpers from 20261109043825, because users can't write
-- job rows. An error anywhere rolls the whole accept back, including any new
-- custom exercises.

-- ---------------------------------------------------------------------------
-- Exercises
-- ---------------------------------------------------------------------------

-- The confirmed match when it's one of the caller's own or predefined
-- exercises; otherwise find-or-create by name. Same name rule and tie-break as
-- map_exercise_for_viewer, so repeated names resolve to one custom exercise:
-- the row created for the first occurrence is what later ones find.
create or replace function public.ai_import_resolve_exercise(
  p_name text,
  p_match jsonb default null
) returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_name text := nullif(trim(p_name), '');
  v_exercise_id uuid;
begin
  -- The Read exercises policy also shows exercises used in other users' public
  -- content, so RLS alone doesn't make an id one this user may build on.
  select e.id into v_exercise_id
  from public.exercises e
  where e.id = (p_match ->> 'exerciseId')::uuid
    and (e.is_predefined or e.user_id = v_user_id);
  if found then
    return v_exercise_id;
  end if;

  if v_name is null then
    raise exception 'invalid_input: an exercise needs a name' using errcode = 'P0001';
  end if;

  select e.id into v_exercise_id
  from public.exercises e
  where (e.is_predefined or e.user_id = v_user_id)
    and lower(trim(e.name)) = lower(v_name)
  order by e.is_predefined desc, e.created_at asc
  limit 1;
  if found then
    return v_exercise_id;
  end if;

  insert into public.exercises (name, is_predefined, user_id)
  values (v_name, false, v_user_id)
  returning id into v_exercise_id;
  return v_exercise_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Flagged content
-- ---------------------------------------------------------------------------

-- Decides where each `unstructured` item is saved, returning its text keyed by
-- position: 'week.day.exercise', 'week.day', 'week', or '' for the top level.
-- `location` is comma-separated text such as "Week 1, Monday, Bench Press". It
-- is matched part by part and the item goes on the deepest thing it names, so
-- content is never lost to an unrecognised location, only placed higher up. An
-- item not placed on an exercise keeps its location as a prefix.
create or replace function public.ai_import_place_notes(p_reviewed jsonb)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_weeks jsonb := coalesce(p_reviewed -> 'weeks', '[]'::jsonb);
  v_days jsonb;
  v_placed jsonb := '{}'::jsonb;
  v_item jsonb;
  v_location text;
  v_parts text[];
  v_text text;
  v_week integer;
  v_day integer;
  v_exercise integer;
  v_key text;
begin
  for v_item in
    select u.value
    from jsonb_array_elements(coalesce(p_reviewed -> 'unstructured', '[]'::jsonb))
      with ordinality u(value, n)
    order by u.n
  loop
    v_text := nullif(trim(v_item ->> 'originalText'), '');
    continue when v_text is null;
    v_location := nullif(trim(v_item ->> 'location'), '');
    v_parts := array(
      select lower(trim(p))
      from regexp_split_to_table(coalesce(v_location, ''), ',') p
    );

    select (w.n - 1)::integer into v_week
    from jsonb_array_elements(v_weeks) with ordinality w(value, n)
    where jsonb_array_length(v_weeks) = 1
      or lower(trim(w.value ->> 'label')) = any (v_parts)
      or 'week ' || w.n = any (v_parts)
    order by w.n
    limit 1;

    v_days := coalesce(v_weeks -> v_week -> 'days', '[]'::jsonb);
    select (d.n - 1)::integer into v_day
    from jsonb_array_elements(v_days) with ordinality d(value, n)
    where jsonb_array_length(v_days) = 1
      or lower(trim(d.value ->> 'title')) = any (v_parts)
      or lower(trim(d.value ->> 'weekday')) = any (v_parts)
      or 'day ' || d.n = any (v_parts)
    order by d.n
    limit 1;

    select (e.n - 1)::integer into v_exercise
    from jsonb_array_elements(coalesce(v_days -> v_day -> 'exercises', '[]'::jsonb))
      with ordinality e(value, n)
    where lower(trim(e.value ->> 'name')) = any (v_parts)
      or lower(trim(e.value -> 'match' ->> 'name')) = any (v_parts)
    order by e.n
    limit 1;

    v_key := case
      when v_exercise is not null then v_week || '.' || v_day || '.' || v_exercise
      when v_day is not null then v_week || '.' || v_day
      when v_week is not null then v_week::text
      else ''
    end;
    if v_exercise is null and v_location is not null then
      v_text := v_location || ': ' || v_text;
    end if;

    v_placed := v_placed
      || jsonb_build_object(v_key, concat_ws(E'\n', v_placed ->> v_key, v_text));
  end loop;

  return v_placed;
end;
$$;

-- ---------------------------------------------------------------------------
-- Sets
-- ---------------------------------------------------------------------------

-- One row per performed set, for either workout_sets or program_sets. An import
-- says "3 x 5" once; the app stores three rows.
create or replace function public.ai_import_exercise_sets(p_exercise jsonb)
returns table (
  set_position integer,
  target_reps integer,
  target_reps_max integer,
  weight_mode text,
  percentage numeric,
  percentage_max numeric,
  absolute_weight_kg numeric,
  rpe_min numeric,
  rpe_max numeric,
  basis_exercise_id uuid,
  note text
)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_set jsonb;
  v_count integer;
  v_next integer := 0;
  v_unreadable text;
begin
  for v_set in
    select s.value
    from jsonb_array_elements(coalesce(p_exercise -> 'sets', '[]'::jsonb))
      with ordinality s(value, n)
    order by s.n
  loop
    v_count := coalesce((v_set ->> 'sets')::integer, 1);
    -- The same bound the extraction flow applies.
    if v_count not between 1 and 50 then
      raise exception 'invalid_input: a set count must be between 1 and 50'
        using errcode = 'P0001';
    end if;

    target_reps := (v_set ->> 'reps')::integer;
    target_reps_max := (v_set ->> 'repsMax')::integer;
    percentage := (v_set ->> 'percent')::numeric;
    percentage_max := (v_set ->> 'percentMax')::numeric;
    rpe_min := (v_set ->> 'rpeMin')::numeric;
    rpe_max := (v_set ->> 'rpeMax')::numeric;
    basis_exercise_id := null;

    if percentage is not null then
      weight_mode := 'percentage';
      absolute_weight_kg := null;
      if jsonb_typeof(v_set -> 'basisExercise') = 'object' then
        basis_exercise_id := public.ai_import_resolve_exercise(
          v_set -> 'basisExercise' ->> 'name',
          v_set -> 'basisExercise' -> 'match'
        );
      end if;
    else
      -- Left null when absent, for the weight_mode_value constraint to refuse.
      weight_mode := 'absolute';
      absolute_weight_kg := (v_set ->> 'weightKg')::numeric;
    end if;

    select string_agg(u.value, ', ') into v_unreadable
    from jsonb_array_elements_text(coalesce(v_set -> 'unreadable', '[]'::jsonb)) u(value);
    note := nullif(concat_ws(
      '. ',
      nullif(trim(v_set ->> 'note'), ''),
      'Could not read: ' || v_unreadable
    ), '');

    for i in 1..v_count loop
      set_position := v_next;
      v_next := v_next + 1;
      return next;
    end loop;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Building the item
-- ---------------------------------------------------------------------------

-- is_copy is what keeps an import private, through the existing CHECK and
-- trigger. There's no author to credit, so copied_from_* stay null.
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
    nullif(concat_ws(
      E'\n', nullif(trim(v_day ->> 'notes'), ''), v_placed ->> '0.0', v_placed ->> '0', v_placed ->> ''
    ), ''),
    false, true, true
  )
  returning id into v_workout_id;

  for v_exercise, v_index in
    select e.value, (e.n - 1)::integer
    from jsonb_array_elements(coalesce(v_day -> 'exercises', '[]'::jsonb))
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

-- Saved, not started (FR-023). program_days.position is 0-based and global
-- across the program because start_program dates each day as start + position;
-- day_number is display-only and restarts each week.
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
  v_exercises jsonb;
  v_exercise jsonb;
  v_exercise_index integer;
  v_program_exercise_id uuid;
begin
  insert into public.programs (
    user_id, name, description, is_public, is_copy, is_imported
  ) values (
    v_user_id,
    coalesce(nullif(trim(p_reviewed ->> 'title'), ''), 'Imported program'),
    v_placed ->> '',
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
      v_exercises := coalesce(v_day -> 'exercises', '[]'::jsonb);

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
        coalesce((v_day ->> 'isRestDay')::boolean, false)
          and jsonb_array_length(v_exercises) = 0,
        nullif(concat_ws(
          E'\n',
          nullif(trim(v_day ->> 'notes'), ''),
          v_placed ->> (v_week_index || '.' || v_day_index)
        ), ''),
        v_position
      )
      returning id into v_program_day_id;
      v_position := v_position + 1;

      for v_exercise, v_exercise_index in
        select e.value, (e.n - 1)::integer
        from jsonb_array_elements(v_exercises) with ordinality e(value, n)
        order by e.n
      loop
        insert into public.program_exercises (
          program_day_id, user_id, exercise_id, position, notes
        ) values (
          v_program_day_id,
          v_user_id,
          public.ai_import_resolve_exercise(v_exercise ->> 'name', v_exercise -> 'match'),
          v_exercise_index,
          nullif(concat_ws(
            E'\n',
            nullif(trim(v_exercise ->> 'notes'), ''),
            v_placed ->> (v_week_index || '.' || v_day_index || '.' || v_exercise_index)
          ), '')
        )
        returning id into v_program_exercise_id;

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

  return v_program_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Accept
-- ---------------------------------------------------------------------------

-- ai_import_claim holds a lock on the job until this transaction ends, so a
-- double tap or second device waits, then gets the item the first one created.
-- The type comes from the job, not the payload: what the user reviewed is the
-- type they asked for, or else the one detected.
create or replace function public.ai_import_accept(
  p_job_id uuid,
  p_reviewed jsonb,
  p_today date
) returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_claim jsonb := public.ai_import_claim(p_job_id);
  v_type text;
  v_workout_id uuid;
  v_program_id uuid;
begin
  if v_claim ->> 'status' = 'accepted' then
    return jsonb_build_object(
      'workout_id', v_claim -> 'workout_id',
      'program_id', v_claim -> 'program_id'
    );
  end if;

  if jsonb_typeof(p_reviewed) is distinct from 'object' then
    raise exception 'invalid_input: the reviewed import is required' using errcode = 'P0001';
  end if;

  select coalesce(j.requested_type, j.detected_type) into v_type
  from public.ai_import_jobs j
  where j.id = p_job_id;

  if v_type = 'workout' then
    v_workout_id := public.ai_import_create_workout(p_reviewed, p_today);
  else
    v_program_id := public.ai_import_create_program(p_reviewed);
  end if;

  perform public.ai_import_mark_accepted(p_job_id, v_workout_id, v_program_id);

  return jsonb_build_object('workout_id', v_workout_id, 'program_id', v_program_id);
end;
$$;

-- Default privileges grant every routine to anon.
revoke all on function public.ai_import_resolve_exercise(text, jsonb) from public, anon;
revoke all on function public.ai_import_place_notes(jsonb) from public, anon;
revoke all on function public.ai_import_exercise_sets(jsonb) from public, anon;
revoke all on function public.ai_import_create_workout(jsonb, date) from public, anon;
revoke all on function public.ai_import_create_program(jsonb) from public, anon;
revoke all on function public.ai_import_accept(uuid, jsonb, date) from public, anon;

grant execute on function public.ai_import_resolve_exercise(text, jsonb) to authenticated;
grant execute on function public.ai_import_place_notes(jsonb) to authenticated;
grant execute on function public.ai_import_exercise_sets(jsonb) to authenticated;
grant execute on function public.ai_import_create_workout(jsonb, date) to authenticated;
grant execute on function public.ai_import_create_program(jsonb) to authenticated;
grant execute on function public.ai_import_accept(uuid, jsonb, date) to authenticated;

-- ---------------------------------------------------------------------------
-- start_program: carry is_imported and the day's notes onto materialized workouts
-- ---------------------------------------------------------------------------

-- Body unchanged from 20261104040520_add_set_ranges_rpe_and_open_load.sql apart
-- from the notes and is_imported columns in the workouts insert. Without the
-- notes, content flagged on a program day would disappear when the program runs.
create or replace function public.start_program(
  p_program_id uuid,
  p_start_date date
) returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_instance_id uuid;
  v_program public.programs%rowtype;
  v_day record;
  v_workout_id uuid;
  v_exercise record;
  v_workout_exercise_id uuid;
  v_set record;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_program
  from public.programs p
  where p.id = p_program_id and p.user_id = v_user_id;

  if not found then
    raise exception 'Program % not found for the current user', p_program_id;
  end if;

  insert into public.program_instances (program_id, user_id, started_at)
  values (p_program_id, v_user_id, p_start_date)
  returning id into v_instance_id;

  -- Every program_day gets a workouts row, including empty rest days — see
  -- program-plan.md Section 12.3. `position` is the day's global,
  -- 0-based order across the whole program and is used as-is for date
  -- math (startDate + position), matching programDayDate() client-side.
  for v_day in
    select pd.*
    from public.program_days pd
    where pd.program_id = p_program_id
    order by pd.position
  loop
    insert into public.workouts (
      user_id, title, date, notes, program_instance_id, program_day_id,
      is_copy, is_imported, copied_from_user_id, copied_from_display_name, copied_from_program_id
    )
    values (
      v_user_id,
      v_day.title,
      p_start_date + v_day.position,
      v_day.notes,
      v_instance_id,
      v_day.id,
      v_program.is_copy,
      v_program.is_imported,
      v_program.copied_from_user_id,
      v_program.copied_from_display_name,
      v_program.copied_from_program_id
    )
    returning id into v_workout_id;

    if not v_day.is_rest_day then
      for v_exercise in
        select pe.*
        from public.program_exercises pe
        where pe.program_day_id = v_day.id
        order by pe.position
      loop
        insert into public.workout_exercises (workout_id, user_id, exercise_id, position, notes)
        values (v_workout_id, v_user_id, v_exercise.exercise_id, v_exercise.position, v_exercise.notes)
        returning id into v_workout_exercise_id;

        for v_set in
          select ps.*
          from public.program_sets ps
          where ps.program_exercise_id = v_exercise.id
          order by ps.position
        loop
          insert into public.workout_sets (
            workout_exercise_id, user_id, position, target_reps, target_reps_max,
            weight_mode, percentage, percentage_max, absolute_weight_kg,
            rpe_min, rpe_max, basis_exercise_id, note
          ) values (
            v_workout_exercise_id, v_user_id, v_set.position, v_set.target_reps,
            v_set.target_reps_max, v_set.weight_mode, v_set.percentage,
            v_set.percentage_max, v_set.absolute_weight_kg,
            v_set.rpe_min, v_set.rpe_max, v_set.basis_exercise_id, v_set.note
          );
        end loop;
      end loop;
    end if;
  end loop;

  return v_instance_id;
end;
$$;
