-- replace_workout_set_group (#145, stage 3a #151): the workout counterpart of
-- replace_program_set_group. The set-row redesign (#148) shows a workout's
-- runs of identical consecutive sets as one group in the editor, and saving
-- an edited group has to rewrite several rows. From the client that would be
-- several requests with no transaction around them, so it's one call here.
--
-- Editing a group replaces its rows with p_count sets of the prescription in
-- p_set, in the same place; later sets keep their order. A count of 0 removes
-- the group. New rows take the logging columns' defaults (not completed, no
-- actual reps, weight or RPE): the editor that calls this is only offered
-- before a session starts, so there's no logged result to lose.
--
-- p_set keys: target_reps, target_reps_max, weight_mode, percentage,
-- percentage_max, absolute_weight_kg (kg), rpe_min, rpe_max,
-- basis_exercise_id, note, set_type. A missing key is null, except set_type,
-- which defaults to 'working'. The set constraints decide what's valid.
--
-- Additive: nothing deployed calls it yet. SECURITY INVOKER, so RLS and the
-- check_parent_owner triggers apply exactly as they would to a direct insert,
-- and the ownership check below refuses anything not the caller's own,
-- including a public workout's sets.

create or replace function public.replace_workout_set_group(
  p_set_ids uuid[],
  p_count integer,
  p_set jsonb
) returns void
language plpgsql
security invoker
set search_path = ''
as $$
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

  select count(*), min(s.workout_exercise_id::text)::uuid, min(s.position), max(s.position)
  into v_found, v_exercise_id, v_lo, v_hi
  from public.workout_sets s
  where s.id = any(p_set_ids) and s.user_id = v_user_id;
  if v_found <> v_k then
    raise exception 'not_found: some of these sets are not available' using errcode = 'P0001';
  end if;
  if exists (
    select 1 from public.workout_sets s
    where s.id = any(p_set_ids) and s.workout_exercise_id <> v_exercise_id
  ) then
    raise exception 'invalid_group: the sets belong to different exercises' using errcode = 'P0001';
  end if;
  -- Consecutive: no other set of the exercise sits inside the group's range.
  if exists (
    select 1 from public.workout_sets s
    where s.workout_exercise_id = v_exercise_id
      and s.position between v_lo and v_hi
      and not (s.id = any(p_set_ids))
  ) then
    raise exception 'invalid_group: the sets are not next to each other' using errcode = 'P0001';
  end if;

  delete from public.workout_sets s where s.id = any(p_set_ids);

  -- workout_sets.position has no unique constraint, so one pass is safe.
  -- After it, later sets sit above the slots the new rows take.
  update public.workout_sets
  set position = position + (p_count - v_k)
  where workout_exercise_id = v_exercise_id and position > v_hi;

  insert into public.workout_sets (
    workout_exercise_id, user_id, position, target_reps, target_reps_max,
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
    coalesce(p_set ->> 'set_type', 'working')
  from generate_series(0, p_count - 1) as g(i);
end;
$$;
revoke execute on function public.replace_workout_set_group(uuid[], integer, jsonb) from public, anon;
grant execute on function public.replace_workout_set_group(uuid[], integer, jsonb) to authenticated;
