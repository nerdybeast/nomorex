-- Workouts archive instead of hard-deleting, like programs. Archiving acts on
-- a whole workout group (every session of one logical workout); the app only
-- hard-deletes a group once it is archived. Additive: the columns default to
-- "not archived", so the app version already in production is unaffected.
alter table public.workouts
  add column is_archived boolean not null default false,
  add column archived_at timestamptz;

create index idx_workouts_active on public.workouts (user_id, date desc)
  where is_archived = false;

-- ---------------------------------------------------------------------------
-- copy_workout: an archived workout is no longer available to copy
-- ---------------------------------------------------------------------------

-- Body unchanged from 20261013023308_add_content_copies.sql apart from the
-- is_archived check, which mirrors copy_program's. workouts_select does not
-- hide archived rows, so this must be explicit.
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
-- profiles_select: an archived public workout no longer exposes its author
-- ---------------------------------------------------------------------------

-- Same as 20260816223137_add_profile_display_name.sql apart from the
-- is_archived filter on the workouts branch, matching the programs branch.
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select to authenticated
  using (
    (select auth.uid()) = id
    or exists (
      select 1 from public.workouts w
      where w.user_id = profiles.id and w.is_public = true and w.is_archived = false
    )
    or exists (
      select 1 from public.programs p
      where p.user_id = profiles.id and p.is_public = true and p.is_archived = false
    )
  );
