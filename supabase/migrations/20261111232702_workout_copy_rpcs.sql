-- Duplicating, repeating and finishing a workout each build a new workout out
-- of an existing one. The app used to do that with one PostgREST call per row
-- and no transaction, so a dropped request left a half-copied workout, and copy
-- attribution was whatever the client chose to send (#35). These functions do
-- the whole walk in one transaction and take attribution from the source row.
--
-- Additive only: finish_workout_session and start_workout_session are
-- unchanged, so the app version already in production keeps working.
-- SECURITY INVOKER throughout, so RLS and the check_parent_owner triggers
-- still apply exactly as they would to a direct client insert.

-- ---------------------------------------------------------------------------
-- copy_workout_tree: the shared exercises + sets copy
-- ---------------------------------------------------------------------------

-- Copies p_source's exercises and their sets onto p_target, both the caller's
-- own. Prescription columns only: completed and actual_* fall back to their
-- defaults, as copy_workout does. Exercise ids are copied as-is because the
-- source is already in the caller's catalog (unlike copy_workout, which maps
-- another user's exercises by name).
create or replace function public.copy_workout_tree(
  p_source_workout_id uuid,
  p_target_workout_id uuid
) returns void
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
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
    rpe_min, rpe_max, basis_exercise_id, note
  )
  select
    se.new_id, v_user_id, ws.position, ws.target_reps, ws.target_reps_max,
    ws.weight_mode, ws.percentage, ws.percentage_max, ws.absolute_weight_kg,
    ws.rpe_min, ws.rpe_max, ws.basis_exercise_id, ws.note
  from public.workout_sets ws
  join src_ex se on se.id = ws.workout_exercise_id;
end;
$$;
revoke execute on function public.copy_workout_tree(uuid, uuid) from public, anon;
-- Invoker functions below need execute on it. Safe for clients to call
-- directly: it checks ownership of both workouts and runs under RLS.
grant execute on function public.copy_workout_tree(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- own_workout: fetch + ownership check shared by the entry points
-- ---------------------------------------------------------------------------

create or replace function public.own_workout(p_workout_id uuid)
returns public.workouts
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_src public.workouts%rowtype;
begin
  if v_user_id is null then
    raise exception 'not_authenticated: sign in required' using errcode = 'P0001';
  end if;
  select * into v_src from public.workouts w
  where w.id = p_workout_id and w.user_id = v_user_id;
  if not found then
    raise exception 'not_found: workout % is not available', p_workout_id
      using errcode = 'P0001';
  end if;
  return v_src;
end;
$$;
revoke execute on function public.own_workout(uuid) from public, anon;
grant execute on function public.own_workout(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- new_workout_from: the workouts row, with attribution from the source
-- ---------------------------------------------------------------------------

-- Inserts a not-started workout derived from the caller's own workout
-- p_source_workout_id and copies its contents. A copy or an import stays one,
-- however the app asks: the attribution columns are read from the source row
-- here, never passed in, so calling this directly can't launder a copy.
create or replace function public.new_workout_from(
  p_source_workout_id uuid,
  p_title text,
  p_today date,
  p_group_id uuid
) returns uuid
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_src public.workouts%rowtype := public.own_workout(p_source_workout_id);
  v_new_id uuid;
begin
  insert into public.workouts (
    user_id, title, date, notes, workout_group_id,
    is_copy, is_imported, copied_from_user_id, copied_from_display_name,
    copied_from_workout_id, copied_from_program_id
  ) values (
    v_src.user_id, p_title, p_today, v_src.notes, coalesce(p_group_id, gen_random_uuid()),
    v_src.is_copy, v_src.is_imported, v_src.copied_from_user_id, v_src.copied_from_display_name,
    v_src.copied_from_workout_id, v_src.copied_from_program_id
  )
  returning id into v_new_id;

  perform public.copy_workout_tree(v_src.id, v_new_id);
  return v_new_id;
end;
$$;
revoke execute on function public.new_workout_from(uuid, text, date, uuid) from public, anon;
grant execute on function public.new_workout_from(uuid, text, date, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- duplicate_workout
-- ---------------------------------------------------------------------------

-- A new, independent workout (its own group) titled "<title> (copy)".
create or replace function public.duplicate_workout(
  p_workout_id uuid,
  p_today date
) returns uuid
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_src public.workouts%rowtype := public.own_workout(p_workout_id);
begin
  if v_src.is_archived then
    raise exception 'archived: workout % is archived', p_workout_id using errcode = 'P0001';
  end if;
  return public.new_workout_from(v_src.id, v_src.title || ' (copy)', p_today, null);
end;
$$;
revoke execute on function public.duplicate_workout(uuid, date) from public, anon;
grant execute on function public.duplicate_workout(uuid, date) to authenticated;

-- ---------------------------------------------------------------------------
-- finish_workout
-- ---------------------------------------------------------------------------

-- Finishes the session and, for a standalone workout, eagerly creates the
-- next not-started instance in the same group, so the Workouts list always
-- has a live row to show. Skipped when a live sibling already exists, and for
-- program-materialized workouts (repeating a program means starting a new
-- run). Returns the new instance's id, or null when none was created.
create or replace function public.finish_workout(
  p_workout_id uuid,
  p_session_notes text,
  p_today date
) returns uuid
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_src public.workouts%rowtype := public.own_workout(p_workout_id);
begin
  perform public.finish_workout_session(p_workout_id, p_session_notes);

  if v_src.program_instance_id is not null then
    return null;
  end if;
  if exists (
    select 1 from public.workouts w
    where w.user_id = v_src.user_id
      and w.workout_group_id = v_src.workout_group_id
      and w.status in ('not_started', 'in_progress', 'paused')
  ) then
    return null;
  end if;

  return public.new_workout_from(v_src.id, v_src.title, p_today, v_src.workout_group_id);
end;
$$;
revoke execute on function public.finish_workout(uuid, text, date) from public, anon;
grant execute on function public.finish_workout(uuid, text, date) to authenticated;

-- ---------------------------------------------------------------------------
-- repeat_workout
-- ---------------------------------------------------------------------------

-- Starts another session of this workout's group: reuses the not-started
-- sibling if there is one (finish_workout normally made it), otherwise
-- creates one, then starts it. A concurrent start trips
-- idx_workouts_one_active_per_group (23505) and rolls the new row back.
create or replace function public.repeat_workout(
  p_workout_id uuid,
  p_today date
) returns uuid
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_src public.workouts%rowtype := public.own_workout(p_workout_id);
  v_sibling record;
  v_target uuid;
begin
  -- Repeating would add a live session to an archived group.
  if v_src.is_archived then
    raise exception 'archived: workout % is archived', p_workout_id using errcode = 'P0001';
  end if;

  select w.id, w.status into v_sibling
  from public.workouts w
  where w.user_id = v_src.user_id
    and w.workout_group_id = v_src.workout_group_id
    and w.status in ('not_started', 'in_progress', 'paused')
  order by (w.status = 'not_started')
  limit 1;

  if found and v_sibling.status <> 'not_started' then
    raise exception 'already_in_progress: this workout is already in progress'
      using errcode = 'P0001';
  end if;

  if found then
    v_target := v_sibling.id;
  else
    v_target := public.new_workout_from(v_src.id, v_src.title, p_today, v_src.workout_group_id);
  end if;

  perform public.start_workout_session(v_target);
  return v_target;
end;
$$;
revoke execute on function public.repeat_workout(uuid, date) from public, anon;
grant execute on function public.repeat_workout(uuid, date) to authenticated;
