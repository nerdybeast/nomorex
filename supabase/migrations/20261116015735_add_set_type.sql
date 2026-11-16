-- Set types (#145, stage 1 #146): every workout and program set is a warm-up,
-- a working set or a cool-down. A set is a working set unless marked
-- otherwise, so the column defaults to 'working', which also fills in every
-- existing row.
--
-- Text with a check constraint rather than a Postgres enum, like weight_mode:
-- a future type is a constraint change, and the app reads an unknown value as
-- a working set.
--
-- Additive: nothing the deployed app sends or selects changes meaning. Each
-- function below is its newest definition (taken from the database) with
-- set_type added to the set insert, so a type survives every copy path.

alter table public.workout_sets
  add column set_type text not null default 'working'
  constraint workout_sets_set_type_check check (set_type in ('warmup', 'working', 'cooldown'));

alter table public.program_sets
  add column set_type text not null default 'working'
  constraint program_sets_set_type_check check (set_type in ('warmup', 'working', 'cooldown'));

-- copy_workout_tree: Shared by duplicate_workout, finish_workout and repeat_workout.
CREATE OR REPLACE FUNCTION public.copy_workout_tree(p_source_workout_id uuid, p_target_workout_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_user_id uuid := (select auth.uid());
begin
  if v_user_id is null then
    raise exception 'not_authenticated: sign in required' using errcode = 'P0001';
  end if;
  if (select count(*) from public.workouts w
      where w.id in (p_source_workout_id, p_target_workout_id)
        and w.user_id = v_user_id) <> 2 then
    raise exception 'not_found: workout is not available' using errcode = 'P0001';
  end if;

  with src_ex as (
    select we.*, gen_random_uuid() as new_id
    from public.workout_exercises we
    where we.workout_id = p_source_workout_id
  ), ins_ex as (
    insert into public.workout_exercises (id, workout_id, user_id, exercise_id, position, notes)
    select new_id, p_target_workout_id, v_user_id, exercise_id, position, notes
    from src_ex
  )
  insert into public.workout_sets (
    workout_exercise_id, user_id, position, target_reps, target_reps_max,
    weight_mode, percentage, percentage_max, absolute_weight_kg,
    rpe_min, rpe_max, basis_exercise_id, note, set_type
  )
  select
    se.new_id, v_user_id, ws.position, ws.target_reps, ws.target_reps_max,
    ws.weight_mode, ws.percentage, ws.percentage_max, ws.absolute_weight_kg,
    ws.rpe_min, ws.rpe_max, ws.basis_exercise_id, ws.note, ws.set_type
  from public.workout_sets ws
  join src_ex se on se.id = ws.workout_exercise_id;
end;
$function$;

-- copy_workout: Saving or starting another user's public workout.
CREATE OR REPLACE FUNCTION public.copy_workout(p_source_workout_id uuid, p_today date, p_start boolean DEFAULT false)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
    rpe_min, rpe_max, basis_exercise_id, note, set_type
  )
  select
    se.new_id, v_user_id, ws.position, ws.target_reps, ws.target_reps_max,
    ws.weight_mode, ws.percentage, ws.percentage_max, ws.absolute_weight_kg,
    ws.rpe_min, ws.rpe_max,
    (v_map ->> ws.basis_exercise_id::text)::uuid, ws.note, ws.set_type
  from public.workout_sets ws
  join src_ex se on se.id = ws.workout_exercise_id;

  if p_start then
    perform public.start_workout_session(v_new_id);
  end if;

  return v_new_id;
end;
$function$;

-- start_program: Materializes program_sets into workout_sets.
CREATE OR REPLACE FUNCTION public.start_program(p_program_id uuid, p_start_date date)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
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
            rpe_min, rpe_max, basis_exercise_id, note, set_type
          ) values (
            v_workout_exercise_id, v_user_id, v_set.position, v_set.target_reps,
            v_set.target_reps_max, v_set.weight_mode, v_set.percentage,
            v_set.percentage_max, v_set.absolute_weight_kg,
            v_set.rpe_min, v_set.rpe_max, v_set.basis_exercise_id, v_set.note,
            v_set.set_type
          );
        end loop;
      end loop;
    end if;
  end loop;

  return v_instance_id;
end;
$function$;

-- copy_program: Saving or starting another user's public program.
CREATE OR REPLACE FUNCTION public.copy_program(p_source_program_id uuid, p_start_date date DEFAULT NULL::date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
    rpe_min, rpe_max, basis_exercise_id, note, set_type
  )
  select
    ex.new_id, v_user_id, ps.position, ps.target_reps, ps.target_reps_max,
    ps.weight_mode, ps.percentage, ps.percentage_max, ps.absolute_weight_kg,
    ps.rpe_min, ps.rpe_max,
    (v_map ->> ps.basis_exercise_id::text)::uuid, ps.note, ps.set_type
  from public.program_sets ps
  join src_ex ex on ex.id = ps.program_exercise_id;

  if p_start_date is not null then
    v_instance_id := public.start_program(v_new_id, p_start_date);
  end if;

  return jsonb_build_object('program_id', v_new_id, 'instance_id', v_instance_id);
end;
$function$;

-- _copy_program_day_contents: Duplicate week, duplicate day and copy day to other weeks.
CREATE OR REPLACE FUNCTION public._copy_program_day_contents(p_source_day_id uuid, p_target_day_id uuid, p_user_id uuid)
 RETURNS void
 LANGUAGE sql
 SET search_path TO ''
AS $function$
  with src_ex as (
    select pe.*, gen_random_uuid() as new_id
    from public.program_exercises pe
    -- Only the caller's own day: reading a public program's rows and
    -- re-inserting them would skip copy_program's attribution.
    where pe.program_day_id = p_source_day_id and pe.user_id = (select auth.uid())
  ), ins_ex as (
    insert into public.program_exercises (id, program_day_id, user_id, exercise_id, position, notes)
    select new_id, p_target_day_id, p_user_id, exercise_id, position, notes
    from src_ex
  )
  insert into public.program_sets (
    program_exercise_id, user_id, position, target_reps, target_reps_max,
    weight_mode, percentage, percentage_max, absolute_weight_kg,
    rpe_min, rpe_max, basis_exercise_id, note, set_type
  )
  select
    ex.new_id, p_user_id, ps.position, ps.target_reps, ps.target_reps_max,
    ps.weight_mode, ps.percentage, ps.percentage_max, ps.absolute_weight_kg,
    ps.rpe_min, ps.rpe_max, ps.basis_exercise_id, ps.note, ps.set_type
  from public.program_sets ps
  join src_ex ex on ex.id = ps.program_exercise_id;
$function$;

-- replace_program_set_group: Rewriting a run of identical sets from the phone program editor. The
-- prescription jsonb gains an optional 'set_type'.
CREATE OR REPLACE FUNCTION public.replace_program_set_group(p_set_ids uuid[], p_count integer, p_set jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_user_id uuid := (select auth.uid());
  v_exercise_id uuid;
  v_found integer;
  v_lo integer;
  v_hi integer;
  v_k integer := coalesce(cardinality(p_set_ids), 0);
begin
  if v_user_id is null then
    raise exception 'not_authenticated: sign in required' using errcode = 'P0001';
  end if;
  if v_k = 0 or p_count is null or p_count < 0 then
    raise exception 'invalid_argument: a group needs its sets and a count of 0 or more'
      using errcode = 'P0001';
  end if;

  select count(*), min(s.program_exercise_id::text)::uuid, min(s.position), max(s.position)
  into v_found, v_exercise_id, v_lo, v_hi
  from public.program_sets s
  where s.id = any(p_set_ids) and s.user_id = v_user_id;
  if v_found <> v_k then
    raise exception 'not_found: some of these sets are not available' using errcode = 'P0001';
  end if;
  if exists (
    select 1 from public.program_sets s
    where s.id = any(p_set_ids) and s.program_exercise_id <> v_exercise_id
  ) then
    raise exception 'invalid_group: the sets belong to different exercises' using errcode = 'P0001';
  end if;
  -- Consecutive: no other set of the exercise sits inside the group's range.
  if exists (
    select 1 from public.program_sets s
    where s.program_exercise_id = v_exercise_id
      and s.position between v_lo and v_hi
      and not (s.id = any(p_set_ids))
  ) then
    raise exception 'invalid_group: the sets are not next to each other' using errcode = 'P0001';
  end if;

  delete from public.program_sets s where s.id = any(p_set_ids);

  -- program_sets.position has no unique constraint, so one pass is safe.
  -- After it, later sets sit above the slots the new rows take.
  update public.program_sets
  set position = position + (p_count - v_k)
  where program_exercise_id = v_exercise_id and position > v_hi;

  insert into public.program_sets (
    program_exercise_id, user_id, position, target_reps, target_reps_max,
    weight_mode, percentage, percentage_max, absolute_weight_kg,
    rpe_min, rpe_max, basis_exercise_id, note, set_type
  )
  select
    v_exercise_id, v_user_id, v_lo + g.i,
    (p_set ->> 'target_reps')::integer,
    (p_set ->> 'target_reps_max')::integer,
    p_set ->> 'weight_mode',
    (p_set ->> 'percentage')::numeric,
    (p_set ->> 'percentage_max')::numeric,
    (p_set ->> 'absolute_weight_kg')::numeric,
    (p_set ->> 'rpe_min')::numeric,
    (p_set ->> 'rpe_max')::numeric,
    (p_set ->> 'basis_exercise_id')::uuid,
    p_set ->> 'note',
    -- Absent from a prescription sent by an app version that predates set
    -- types: the group stays working sets, as it was.
    coalesce(p_set ->> 'set_type', 'working')
  from generate_series(0, p_count - 1) as g(i);
end;
$function$;
