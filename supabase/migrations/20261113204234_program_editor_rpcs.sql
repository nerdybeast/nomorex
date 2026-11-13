-- Server functions for the phone program editor (#126, stage #127).
--
-- Duplicating a week, copying a day to other weeks, and replacing a group of
-- identical sets each touch many rows and renumber positions under unique
-- constraints, so each is one transaction here rather than a client loop that
-- could stop halfway.
--
-- All three are SECURITY INVOKER: RLS and the check_parent_owner() triggers
-- decide ownership exactly as they would for direct inserts. Each still checks
-- ownership itself first, because program content is readable by others when
-- the program is public, and a clear not_found beats a half-applied update
-- that RLS silently filtered.

-- ---------------------------------------------------------------------------
-- Shared: copy one day's exercises and sets onto another day
-- ---------------------------------------------------------------------------

create or replace function public._copy_program_day_contents(
  p_source_day_id uuid,
  p_target_day_id uuid,
  p_user_id uuid
) returns void
language sql
security invoker
set search_path = ''
as $$
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
    rpe_min, rpe_max, basis_exercise_id, note
  )
  select
    ex.new_id, p_user_id, ps.position, ps.target_reps, ps.target_reps_max,
    ps.weight_mode, ps.percentage, ps.percentage_max, ps.absolute_weight_kg,
    ps.rpe_min, ps.rpe_max, ps.basis_exercise_id, ps.note
  from public.program_sets ps
  join src_ex ex on ex.id = ps.program_exercise_id;
$$;
revoke execute on function public._copy_program_day_contents(uuid, uuid, uuid) from public, anon;
grant execute on function public._copy_program_day_contents(uuid, uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Shared: open a gap in a program's global day positions
-- ---------------------------------------------------------------------------

-- Moves every day of the program positioned after p_after up by p_by.
-- unique(program_id, position) is checked per row, so a plain "+ p_by" can
-- collide with a neighbour mid-update; going through negatives first can't.
create or replace function public._shift_program_days(
  p_program_id uuid,
  p_after integer,
  p_by integer
) returns void
language sql
security invoker
set search_path = ''
as $$
  update public.program_days
  set position = -(position + p_by) - 1
  where program_id = p_program_id and position > p_after;
  update public.program_days
  set position = -position - 1
  where program_id = p_program_id and position < 0;
$$;
revoke execute on function public._shift_program_days(uuid, integer, integer) from public, anon;
grant execute on function public._shift_program_days(uuid, integer, integer) to authenticated;

-- ---------------------------------------------------------------------------
-- duplicate_program_week
-- ---------------------------------------------------------------------------

-- Inserts a copy of the week right after it, with its days, exercises and
-- sets. Later weeks move up one week number; later days move up by the
-- number of days copied, so the global day order stays intact. Returns the
-- new week's id.
create or replace function public.duplicate_program_week(p_week_id uuid)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_src public.program_weeks%rowtype;
  v_new_week_id uuid := gen_random_uuid();
  v_last_pos integer;
  v_day_count integer;
  v_day record;
  v_new_day_id uuid;
  v_i integer := 0;
begin
  if v_user_id is null then
    raise exception 'not_authenticated: sign in required' using errcode = 'P0001';
  end if;

  select * into v_src from public.program_weeks w
  where w.id = p_week_id and w.user_id = v_user_id;
  if not found then
    raise exception 'not_found: week % is not available', p_week_id using errcode = 'P0001';
  end if;

  -- Later weeks up by one. unique(program_id, week_number): negatives first.
  update public.program_weeks
  set week_number = -(week_number + 1), position = position + 1
  where program_id = v_src.program_id and week_number > v_src.week_number;
  update public.program_weeks
  set week_number = -week_number
  where program_id = v_src.program_id and week_number < 0;

  insert into public.program_weeks (id, program_id, user_id, week_number, label, notes, position)
  values (
    v_new_week_id, v_src.program_id, v_user_id, v_src.week_number + 1,
    case when v_src.label is null then null else v_src.label || ' (copy)' end,
    v_src.notes, v_src.position + 1
  );

  select count(*), max(d.position) into v_day_count, v_last_pos
  from public.program_days d where d.program_week_id = v_src.id;

  if v_day_count > 0 then
    perform public._shift_program_days(v_src.program_id, v_last_pos, v_day_count);
    for v_day in
      select * from public.program_days d where d.program_week_id = v_src.id order by d.position
    loop
      v_i := v_i + 1;
      v_new_day_id := gen_random_uuid();
      insert into public.program_days (
        id, program_id, program_week_id, user_id, day_number, title, is_rest_day, notes, position
      ) values (
        v_new_day_id, v_src.program_id, v_new_week_id, v_user_id,
        v_day.day_number, v_day.title, v_day.is_rest_day, v_day.notes, v_last_pos + v_i
      );
      perform public._copy_program_day_contents(v_day.id, v_new_day_id, v_user_id);
    end loop;
  end if;

  return v_new_week_id;
end;
$$;
revoke execute on function public.duplicate_program_week(uuid) from public, anon;
grant execute on function public.duplicate_program_week(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- copy_program_day
-- ---------------------------------------------------------------------------

-- Appends a copy of the day to the end of each target week, in the order
-- given. The day's own week is allowed: that's Duplicate day. Every target
-- must be a week of the same program. Returns the new days' ids, in order.
create or replace function public.copy_program_day(p_day_id uuid, p_week_ids uuid[])
returns uuid[]
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_src public.program_days%rowtype;
  v_week public.program_weeks%rowtype;
  v_week_id uuid;
  v_after integer;
  v_new_day_id uuid;
  v_out uuid[] := '{}'::uuid[];
begin
  if v_user_id is null then
    raise exception 'not_authenticated: sign in required' using errcode = 'P0001';
  end if;
  if p_week_ids is null or cardinality(p_week_ids) = 0 then
    raise exception 'invalid_argument: choose at least one week' using errcode = 'P0001';
  end if;

  select * into v_src from public.program_days d
  where d.id = p_day_id and d.user_id = v_user_id;
  if not found then
    raise exception 'not_found: day % is not available', p_day_id using errcode = 'P0001';
  end if;

  foreach v_week_id in array p_week_ids loop
    select * into v_week from public.program_weeks w
    where w.id = v_week_id and w.user_id = v_user_id and w.program_id = v_src.program_id;
    if not found then
      raise exception 'not_found: week % is not available', v_week_id using errcode = 'P0001';
    end if;

    -- The new day goes after the week's last day; an empty week takes the
    -- slot after the last day of the weeks before it.
    select coalesce(max(d.position), -1) into v_after
    from public.program_days d
    join public.program_weeks w on w.id = d.program_week_id
    where d.program_id = v_src.program_id
      and (w.id = v_week.id or w.week_number < v_week.week_number);

    perform public._shift_program_days(v_src.program_id, v_after, 1);

    v_new_day_id := gen_random_uuid();
    insert into public.program_days (
      id, program_id, program_week_id, user_id, day_number, title, is_rest_day, notes, position
    ) values (
      v_new_day_id, v_src.program_id, v_week.id, v_user_id,
      (select count(*) + 1 from public.program_days d where d.program_week_id = v_week.id),
      v_src.title, v_src.is_rest_day, v_src.notes, v_after + 1
    );
    perform public._copy_program_day_contents(v_src.id, v_new_day_id, v_user_id);
    v_out := v_out || v_new_day_id;
  end loop;

  return v_out;
end;
$$;
revoke execute on function public.copy_program_day(uuid, uuid[]) from public, anon;
grant execute on function public.copy_program_day(uuid, uuid[]) to authenticated;

-- ---------------------------------------------------------------------------
-- replace_program_set_group
-- ---------------------------------------------------------------------------

-- The editor shows runs of identical consecutive sets as one group ("10 × 1
-- @ 80%"). Editing a group replaces its rows with p_count sets of the
-- prescription in p_set, in the same place; later sets keep their order.
-- A count of 0 removes the group. program_sets hold no logged data and
-- nothing references them, so replacing rows loses nothing.
--
-- p_set keys: target_reps, target_reps_max, weight_mode, percentage,
-- percentage_max, absolute_weight_kg (kg), rpe_min, rpe_max,
-- basis_exercise_id, note. A missing key is null. The set constraints decide
-- what's valid.
create or replace function public.replace_program_set_group(
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
    rpe_min, rpe_max, basis_exercise_id, note
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
    p_set ->> 'note'
  from generate_series(0, p_count - 1) as g(i);
end;
$$;
revoke execute on function public.replace_program_set_group(uuid[], integer, jsonb) from public, anon;
grant execute on function public.replace_program_set_group(uuid[], integer, jsonb) to authenticated;
