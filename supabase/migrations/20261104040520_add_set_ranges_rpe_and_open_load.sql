-- Sets can prescribe ranges and effort, not just one rep count and one load
-- (#61, #62): "3 x 7-9 @ 67-72.5% RPE 6-7", and "choose your own load" sets.
--
-- Additive: every new column is nullable and means "same as today" when null,
-- so existing rows and the app version already in production are unaffected.
-- The one new value a production app can meet is weight_mode = 'open'; the
-- current client treats any non-'percentage' set as absolute and renders a
-- null absolute_weight_kg as "0 kg" / "? kg" (no crash) until the open-load
-- UI (#66) ships. Nothing writes 'open' before then.

-- ---------------------------------------------------------------------------
-- Columns
-- ---------------------------------------------------------------------------

-- target_reps_max: top of a rep range; null = a single rep count (target_reps).
-- percentage_max:  top of a %1RM range; null = a single percentage.
-- rpe_min/rpe_max: target effort (1-10, half steps allowed); rpe_max null =
--                  a single RPE.
alter table public.program_sets
  add column target_reps_max integer,
  add column percentage_max numeric,
  add column rpe_min numeric(3,1),
  add column rpe_max numeric(3,1);

alter table public.workout_sets
  add column target_reps_max integer,
  add column percentage_max numeric,
  add column rpe_min numeric(3,1),
  add column rpe_max numeric(3,1),
  -- Logging-only, like actual_reps/actual_weight_kg: never copied.
  add column actual_rpe numeric(3,1);

-- ---------------------------------------------------------------------------
-- weight_mode: add 'open' (no prescribed load; the lifter picks it)
-- ---------------------------------------------------------------------------

-- program_sets had an inline column check (default name) plus the value check.
alter table public.program_sets
  drop constraint if exists program_sets_weight_mode_check,
  drop constraint if exists program_sets_weight_mode_value;

alter table public.program_sets
  add constraint program_sets_weight_mode_check
    check (weight_mode in ('percentage', 'absolute', 'open')),
  add constraint program_sets_weight_mode_value check (
    (weight_mode = 'percentage' and percentage is not null)
    or (weight_mode = 'absolute' and absolute_weight_kg is not null)
    or (weight_mode = 'open' and percentage is null and absolute_weight_kg is null)
  );

-- workout_sets' two checks come from 20260802012717_remote_schema.sql; the
-- value check's name has no table prefix there, so it's renamed on the way.
alter table public.workout_sets
  drop constraint if exists workout_sets_weight_mode_check,
  drop constraint if exists weight_mode_value;

alter table public.workout_sets
  add constraint workout_sets_weight_mode_check
    check (weight_mode in ('percentage', 'absolute', 'open')),
  add constraint workout_sets_weight_mode_value check (
    (weight_mode = 'percentage' and percentage is not null)
    or (weight_mode = 'absolute' and absolute_weight_kg is not null)
    or (weight_mode = 'open' and percentage is null and absolute_weight_kg is null)
  );

-- ---------------------------------------------------------------------------
-- Range / RPE sanity (the upper end only exists alongside, and above, the lower)
-- ---------------------------------------------------------------------------

alter table public.program_sets
  add constraint program_sets_target_reps_range check (
    target_reps_max is null
    or (target_reps is not null and target_reps_max >= target_reps)
  ),
  add constraint program_sets_percentage_range check (
    percentage_max is null
    or (weight_mode = 'percentage' and percentage_max >= percentage)
  ),
  add constraint program_sets_rpe_range check (
    (rpe_min is null or rpe_min between 1 and 10)
    and (rpe_max is null or (rpe_min is not null and rpe_max between rpe_min and 10))
  );

alter table public.workout_sets
  add constraint workout_sets_target_reps_range check (
    target_reps_max is null
    or (target_reps is not null and target_reps_max >= target_reps)
  ),
  add constraint workout_sets_percentage_range check (
    percentage_max is null
    or (weight_mode = 'percentage' and percentage_max >= percentage)
  ),
  add constraint workout_sets_rpe_range check (
    (rpe_min is null or rpe_min between 1 and 10)
    and (rpe_max is null or (rpe_min is not null and rpe_max between rpe_min and 10))
  ),
  add constraint workout_sets_actual_rpe_range check (
    actual_rpe is null or actual_rpe between 1 and 10
  );

-- ---------------------------------------------------------------------------
-- start_program: carry the new template columns onto materialized sets
-- ---------------------------------------------------------------------------

-- Body unchanged from 20261013023308_add_content_copies.sql apart from the
-- target_reps_max / percentage_max / rpe_min / rpe_max columns in the
-- workout_sets insert.
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
      user_id, title, date, program_instance_id, program_day_id,
      is_copy, copied_from_user_id, copied_from_display_name, copied_from_program_id
    )
    values (
      v_user_id,
      v_day.title,
      p_start_date + v_day.position,
      v_instance_id,
      v_day.id,
      v_program.is_copy,
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

-- ---------------------------------------------------------------------------
-- copy_program: carry the new template columns onto the copy
-- ---------------------------------------------------------------------------

-- Body unchanged from 20261013023308_add_content_copies.sql apart from the
-- new columns in the program_sets insert.
create or replace function public.copy_program(
  p_source_program_id uuid,
  p_start_date date default null
) returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_src public.programs%rowtype;
  v_new_id uuid;
  v_instance_id uuid;
  v_map jsonb := '{}'::jsonb;
  v_exercise_id uuid;
begin
  if v_user_id is null then
    raise exception 'not_authenticated: sign in required' using errcode = 'P0001';
  end if;

  select * into v_src from public.programs p where p.id = p_source_program_id;
  if not found then
    raise exception 'not_found: program % is not available', p_source_program_id
      using errcode = 'P0001';
  end if;
  if v_src.user_id = v_user_id then
    raise exception 'own_content: program % is already yours', p_source_program_id
      using errcode = 'P0001';
  end if;
  if not v_src.is_public then
    raise exception 'not_found: program % is not available', p_source_program_id
      using errcode = 'P0001';
  end if;
  -- programs_select does not hide archived rows, so this must be explicit.
  if v_src.is_archived then
    raise exception 'archived: program % is archived', p_source_program_id
      using errcode = 'P0001';
  end if;
  if v_src.is_copy then
    raise exception 'source_is_copy: program % is itself a copy', p_source_program_id
      using errcode = 'P0001';
  end if;

  for v_exercise_id in
    select pe.exercise_id
    from public.program_exercises pe
    join public.program_days pd on pd.id = pe.program_day_id
    where pd.program_id = v_src.id
    union
    select ps.basis_exercise_id
    from public.program_sets ps
    join public.program_exercises pe on pe.id = ps.program_exercise_id
    join public.program_days pd on pd.id = pe.program_day_id
    where pd.program_id = v_src.id and ps.basis_exercise_id is not null
  loop
    v_map := v_map || jsonb_build_object(
      v_exercise_id::text, public.map_exercise_for_viewer(v_exercise_id));
  end loop;

  insert into public.programs (
    user_id, name, description, is_public, is_archived,
    is_copy, copied_from_user_id, copied_from_display_name, copied_from_program_id
  ) values (
    v_user_id, v_src.name, v_src.description, false, false,
    true, v_src.user_id,
    (select p.display_name from public.profiles p where p.id = v_src.user_id),
    v_src.id
  )
  returning id into v_new_id;

  with src_wk as (
    select pw.*, gen_random_uuid() as new_id
    from public.program_weeks pw
    where pw.program_id = v_src.id
  ), ins_wk as (
    insert into public.program_weeks (id, program_id, user_id, week_number, label, notes, position)
    select new_id, v_new_id, v_user_id, week_number, label, notes, position
    from src_wk
  ), src_dy as (
    select pd.*, gen_random_uuid() as new_id, wk.new_id as new_week_id
    from public.program_days pd
    join src_wk wk on wk.id = pd.program_week_id
  ), ins_dy as (
    insert into public.program_days (
      id, program_id, program_week_id, user_id, day_number, title, is_rest_day, notes, position
    )
    select new_id, v_new_id, new_week_id, v_user_id, day_number, title, is_rest_day, notes, position
    from src_dy
  ), src_ex as (
    select pe.*, gen_random_uuid() as new_id, dy.new_id as new_day_id
    from public.program_exercises pe
    join src_dy dy on dy.id = pe.program_day_id
  ), ins_ex as (
    insert into public.program_exercises (id, program_day_id, user_id, exercise_id, position, notes)
    select new_id, new_day_id, v_user_id, (v_map ->> exercise_id::text)::uuid, position, notes
    from src_ex
  )
  insert into public.program_sets (
    program_exercise_id, user_id, position, target_reps, target_reps_max,
    weight_mode, percentage, percentage_max, absolute_weight_kg,
    rpe_min, rpe_max, basis_exercise_id, note
  )
  select
    ex.new_id, v_user_id, ps.position, ps.target_reps, ps.target_reps_max,
    ps.weight_mode, ps.percentage, ps.percentage_max, ps.absolute_weight_kg,
    ps.rpe_min, ps.rpe_max,
    (v_map ->> ps.basis_exercise_id::text)::uuid, ps.note
  from public.program_sets ps
  join src_ex ex on ex.id = ps.program_exercise_id;

  if p_start_date is not null then
    v_instance_id := public.start_program(v_new_id, p_start_date);
  end if;

  return jsonb_build_object('program_id', v_new_id, 'instance_id', v_instance_id);
end;
$$;

revoke execute on function public.copy_program(uuid, date) from public, anon;
grant execute on function public.copy_program(uuid, date) to authenticated;

-- ---------------------------------------------------------------------------
-- copy_workout: carry the new template columns onto the copy
-- ---------------------------------------------------------------------------

-- Body unchanged from 20261027023100_archive_workouts.sql apart from the new
-- template columns in the workout_sets insert. actual_rpe is a logged result
-- and, like completed/actual_*, is deliberately not copied (FR-006).
create or replace function public.copy_workout(
  p_source_workout_id uuid,
  p_today date,
  p_start boolean default false
) returns uuid
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_src public.workouts%rowtype;
  v_new_id uuid;
  v_map jsonb := '{}'::jsonb;
  v_exercise_id uuid;
begin
  if v_user_id is null then
    raise exception 'not_authenticated: sign in required' using errcode = 'P0001';
  end if;

  select * into v_src from public.workouts w where w.id = p_source_workout_id;
  if not found then
    raise exception 'not_found: workout % is not available', p_source_workout_id
      using errcode = 'P0001';
  end if;
  if v_src.user_id = v_user_id then
    raise exception 'own_content: workout % is already yours', p_source_workout_id
      using errcode = 'P0001';
  end if;
  if not v_src.is_public then
    raise exception 'not_found: workout % is not available', p_source_workout_id
      using errcode = 'P0001';
  end if;
  if v_src.is_archived then
    raise exception 'archived: workout % is archived', p_source_workout_id
      using errcode = 'P0001';
  end if;
  if v_src.is_copy then
    raise exception 'source_is_copy: workout % is itself a copy', p_source_workout_id
      using errcode = 'P0001';
  end if;

  -- Resolve each distinct exercise once (SC-006: no duplicate custom rows).
  for v_exercise_id in
    select we.exercise_id
    from public.workout_exercises we
    where we.workout_id = v_src.id
    union
    select ws.basis_exercise_id
    from public.workout_sets ws
    join public.workout_exercises we on we.id = ws.workout_exercise_id
    where we.workout_id = v_src.id and ws.basis_exercise_id is not null
  loop
    v_map := v_map || jsonb_build_object(
      v_exercise_id::text, public.map_exercise_for_viewer(v_exercise_id));
  end loop;

  insert into public.workouts (
    user_id, title, date, notes, is_public,
    is_copy, copied_from_user_id, copied_from_display_name, copied_from_workout_id
  ) values (
    v_user_id, v_src.title, p_today, v_src.notes, false,
    true, v_src.user_id,
    (select p.display_name from public.profiles p where p.id = v_src.user_id),
    v_src.id
  )
  returning id into v_new_id;

  -- Template columns only: completed/actual_* stay at their defaults (FR-006).
  with src_ex as (
    select we.*, gen_random_uuid() as new_id
    from public.workout_exercises we
    where we.workout_id = v_src.id
  ), ins_ex as (
    insert into public.workout_exercises (id, workout_id, user_id, exercise_id, position, notes)
    select new_id, v_new_id, v_user_id, (v_map ->> exercise_id::text)::uuid, position, notes
    from src_ex
  )
  insert into public.workout_sets (
    workout_exercise_id, user_id, position, target_reps, target_reps_max,
    weight_mode, percentage, percentage_max, absolute_weight_kg,
    rpe_min, rpe_max, basis_exercise_id, note
  )
  select
    se.new_id, v_user_id, ws.position, ws.target_reps, ws.target_reps_max,
    ws.weight_mode, ws.percentage, ws.percentage_max, ws.absolute_weight_kg,
    ws.rpe_min, ws.rpe_max,
    (v_map ->> ws.basis_exercise_id::text)::uuid, ws.note
  from public.workout_sets ws
  join src_ex se on se.id = ws.workout_exercise_id;

  if p_start then
    perform public.start_workout_session(v_new_id);
  end if;

  return v_new_id;
end;
$$;

revoke execute on function public.copy_workout(uuid, date, boolean) from public, anon;
grant execute on function public.copy_workout(uuid, date, boolean) to authenticated;
