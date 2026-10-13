-- Save / start another user's public workout or program as your own copy
-- (specs/001-save-community-content).
--
-- A copy is an ordinary workout/program owned by the viewer, permanently
-- marked `is_copy` with a snapshot of the original author's name. Copies can
-- never be made public (CHECK + trigger below), and copy status is inherited by
-- anything derived from a copy — start_program stamps it onto materialized
-- workouts; the client carries it through duplicate/repeat.
--
-- Additive only: new nullable/defaulted columns, a CHECK every existing row
-- already satisfies (is_copy defaults false), new functions, and a
-- signature-compatible start_program replacement. Ships ahead of the app code.

-- ---------------------------------------------------------------------------
-- Attribution columns
-- ---------------------------------------------------------------------------

-- copied_from_display_name is a snapshot, not a join: profiles_select only
-- exposes an author's profile while they still have something public, so a
-- live join would go blank the moment the author unpublishes.
--
-- copied_from_user_id references auth.users, NOT public.profiles, on purpose:
-- workouts/programs already have a user_id FK to profiles, and a second FK to
-- the same table makes PostgREST reject every existing `profiles(display_name)`
-- embed as ambiguous (PGRST201) — which would break the Community screens of
-- the app version already in production the moment this migration lands.
-- auth isn't exposed through PostgREST, so this FK adds no relationship there,
-- and deleting the author's account still nulls it out.
alter table public.workouts
  add column is_copy boolean not null default false,
  add column copied_from_user_id uuid null
    references auth.users (id) on delete set null,
  add column copied_from_display_name text null,
  add column copied_from_workout_id uuid null
    references public.workouts (id) on delete set null,
  -- Set only on workouts materialized from a copied program, so their label
  -- can still name the author while the original program exists.
  add column copied_from_program_id uuid null
    references public.programs (id) on delete set null,
  add constraint workouts_copy_not_public check (not (is_copy and is_public));

create index idx_workouts_copied_from_workout
  on public.workouts (user_id, copied_from_workout_id)
  where copied_from_workout_id is not null;
create index idx_workouts_copied_from_user_id on public.workouts (copied_from_user_id);
create index idx_workouts_copied_from_program_id on public.workouts (copied_from_program_id);

alter table public.programs
  add column is_copy boolean not null default false,
  add column copied_from_user_id uuid null
    references auth.users (id) on delete set null,
  add column copied_from_display_name text null,
  add column copied_from_program_id uuid null
    references public.programs (id) on delete set null,
  add constraint programs_copy_not_public check (not (is_copy and is_public));

create index idx_programs_copied_from_program
  on public.programs (user_id, copied_from_program_id)
  where copied_from_program_id is not null;
create index idx_programs_copied_from_user_id on public.programs (copied_from_user_id);

-- ---------------------------------------------------------------------------
-- A copy stays a copy
-- ---------------------------------------------------------------------------

-- Ownership RLS lets a user update any column on their own rows, so without
-- this a client could clear is_copy and then publish. Guards only is_copy —
-- the copied_from_* FKs must stay free to be nulled by their ON DELETE SET
-- NULL cascades.
create or replace function public.prevent_uncopy()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
begin
  if old.is_copy and not new.is_copy then
    raise exception 'copy_is_permanent: a copy cannot be un-marked'
      using errcode = 'P0001';
  end if;
  return new;
end;
$$;

-- Trigger functions never need EXECUTE to fire.
revoke execute on function public.prevent_uncopy() from public, anon, authenticated;

create trigger workouts_prevent_uncopy
  before update on public.workouts
  for each row execute function public.prevent_uncopy();

create trigger programs_prevent_uncopy
  before update on public.programs
  for each row execute function public.prevent_uncopy();

-- ---------------------------------------------------------------------------
-- Exercise mapping
-- ---------------------------------------------------------------------------

-- The caller's exercise matching another user's exercise by name. An
-- exercises.id only means something inside one user's catalog, so across users
-- the match is on lower(trim(name)) — the same rule oneRepMaxByNameProvider
-- and ExercisesNotifier.ensureExerciseByName use, so a copied set's 1RM
-- resolves whichever same-named row is picked. Predefined wins, then the
-- oldest custom row; a custom exercise is created only when the caller has no
-- match. Null in, null out (for nullable basis_exercise_id).
create or replace function public.map_exercise_for_viewer(p_source_exercise_id uuid)
returns uuid
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_source record;
  v_match uuid;
begin
  if p_source_exercise_id is null then
    return null;
  end if;

  select e.id, e.name, e.is_predefined into v_source
  from public.exercises e
  where e.id = p_source_exercise_id;

  if not found then
    raise exception 'not_found: exercise % is not readable', p_source_exercise_id
      using errcode = 'P0001';
  end if;

  if v_source.is_predefined then
    return v_source.id;
  end if;

  select e.id into v_match
  from public.exercises e
  where (e.is_predefined = true or e.user_id = v_user_id)
    and lower(trim(e.name)) = lower(trim(v_source.name))
  order by e.is_predefined desc, e.created_at asc
  limit 1;

  if v_match is not null then
    return v_match;
  end if;

  insert into public.exercises (name, is_predefined, user_id)
  values (trim(v_source.name), false, v_user_id)
  returning id into v_match;

  return v_match;
end;
$$;

revoke execute on function public.map_exercise_for_viewer(uuid) from public, anon;
grant execute on function public.map_exercise_for_viewer(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- copy_workout
-- ---------------------------------------------------------------------------

-- Server-side and SECURITY INVOKER for the same reasons as start_program:
-- one transaction (a failed copy leaves nothing behind), and every read/write
-- stays gated by the caller's RLS — the source is readable only because it's
-- public. p_today is the caller's local date (current_date is UTC, and every
-- other workout-creation path dates rows by the device's local day).
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
    workout_exercise_id, user_id, position, target_reps, weight_mode,
    percentage, absolute_weight_kg, basis_exercise_id, note
  )
  select
    se.new_id, v_user_id, ws.position, ws.target_reps, ws.weight_mode,
    ws.percentage, ws.absolute_weight_kg,
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

-- ---------------------------------------------------------------------------
-- start_program: stamp copy attribution onto materialized workouts
-- ---------------------------------------------------------------------------

-- Body unchanged from 20260805020858_create_start_program_function.sql apart
-- from carrying the program's copy attribution onto every workout it creates,
-- so runs of a copied program inherit copy status (FR-008a).
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
            workout_exercise_id, user_id, position, target_reps, weight_mode,
            percentage, absolute_weight_kg, basis_exercise_id, note
          ) values (
            v_workout_exercise_id, v_user_id, v_set.position, v_set.target_reps,
            v_set.weight_mode, v_set.percentage, v_set.absolute_weight_kg,
            v_set.basis_exercise_id, v_set.note
          );
        end loop;
      end loop;
    end if;
  end loop;

  return v_instance_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- copy_program
-- ---------------------------------------------------------------------------

-- Copies the whole weeks -> days -> exercises -> sets tree in one statement
-- (old -> new ids pre-generated per level), so a 12-week program is a handful
-- of set-based inserts rather than thousands of row loops (SC-003). Positions,
-- week numbers and day numbers are copied as-is from a valid source, never
-- recomputed. With p_start_date, the copy is started via start_program inside
-- the same transaction — the caller owns the copy, so the existing ownership
-- check passes and scheduling is identical to starting one's own program.
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
    program_exercise_id, user_id, position, target_reps, weight_mode,
    percentage, absolute_weight_kg, basis_exercise_id, note
  )
  select
    ex.new_id, v_user_id, ps.position, ps.target_reps, ps.weight_mode,
    ps.percentage, ps.absolute_weight_kg,
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
