-- A program week is a calendar week: at most 7 days, and it always takes 7
-- days of the schedule, however many it holds.
--
-- Before this, weeks had no size limit and start_program dated each day as
-- start + position (the day's global order). A 20-day import landed in one
-- week, and a week of 3 days was followed straight away by the next week's
-- days. Now:
--
--   1. Existing weeks over 7 days are split into weeks of 7, in order, and
--      "Day N" titles restart at Day 1 in each week.
--   2. A trigger refuses an 8th day in a week, on every path (the editor,
--      copy_program_day, duplicate_program_week, copy_program, AI import).
--   3. add_program_week adds a week with 7 rest days (Day 1–7); a rest day
--      turns into a training day when an exercise is added to it.
--      add_program_day adds one day at the end of a week that has room.
--   4. start_program dates a day as start + 7 × (its week's index) + (its
--      place in the week). programDayDate() and Program.fromJson mirror this
--      client-side. `position` still orders days, but its value no longer
--      sets a date, so gaps left by deleted days don't move anything.
--
-- Breaking for programs already in beta (allowed until launch, see CLAUDE.md
-- "CI/CD"): split weeks get new week numbers, and a run started after this
-- dates short weeks differently.

-- ---------------------------------------------------------------------------
-- 1. Split weeks over 7 days
-- ---------------------------------------------------------------------------

do $$
declare
  v_week record;
  v_extra integer;
  v_new_week_id uuid;
  k integer;
begin
  -- Later weeks first: splitting a week only moves the weeks after it, so the
  -- earlier weeks still to come keep the numbers this query read.
  for v_week in
    select w.*, c.n
    from public.program_weeks w
    join (
      select program_week_id, count(*)::integer as n
      from public.program_days
      group by program_week_id
      having count(*) > 7
    ) c on c.program_week_id = w.id
    order by w.program_id, w.week_number desc
  loop
    v_extra := (v_week.n - 1) / 7;

    -- Make room after the week. unique(program_id, week_number): negatives
    -- first, as reorder_program_weeks does.
    update public.program_weeks
    set week_number = -(week_number + v_extra), position = position + v_extra
    where program_id = v_week.program_id and week_number > v_week.week_number;
    update public.program_weeks
    set week_number = -week_number
    where program_id = v_week.program_id and week_number < 0;

    -- Highest chunk first, so the lower chunks' places in the week don't move.
    for k in reverse v_extra..1 loop
      insert into public.program_weeks (program_id, user_id, week_number, position)
      values (v_week.program_id, v_week.user_id, v_week.week_number + k, v_week.position + k)
      returning id into v_new_week_id;

      update public.program_days
      set program_week_id = v_new_week_id
      where id in (
        select s.id from (
          select d.id, row_number() over (order by d.position) - 1 as slot
          from public.program_days d
          where d.program_week_id = v_week.id
        ) s
        where s.slot >= 7 * k and s.slot < 7 * (k + 1)
      );
    end loop;
  end loop;
end;
$$;

-- day_number is each day's place in its week, and generated "Day N" titles
-- follow it, so every week reads Day 1–7. Titles a user wrote stay.
update public.program_days d
set day_number = s.slot + 1,
    title = case when d.title ~ '^Day \d+$' then 'Day ' || (s.slot + 1) else d.title end
from (
  select id, row_number() over (partition by program_week_id order by position) - 1 as slot
  from public.program_days
) s
where s.id = d.id
  and (d.day_number <> s.slot + 1 or (d.title ~ '^Day \d+$' and d.title <> 'Day ' || (s.slot + 1)));

-- ---------------------------------------------------------------------------
-- 2. At most 7 days in a week
-- ---------------------------------------------------------------------------

-- AFTER ROW, like check_parent_owner: it runs at the end of the statement, so
-- a bulk insert (copy_program, the AI import) is counted whole. The lock on
-- the week makes two concurrent adds count one after the other. SECURITY
-- INVOKER: the writer only ever adds to their own week (check_parent_owner),
-- which they can see and lock.
create function public.enforce_program_week_day_limit()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  perform 1 from public.program_weeks w where w.id = new.program_week_id for update;
  if (select count(*) from public.program_days d where d.program_week_id = new.program_week_id) > 7 then
    raise exception 'week_full: a week has at most 7 days' using errcode = 'P0001';
  end if;
  return null;
end;
$$;
revoke execute on function public.enforce_program_week_day_limit() from public, anon;

create trigger program_days_week_day_limit
  after insert or update of program_week_id on public.program_days
  for each row execute function public.enforce_program_week_day_limit();

-- ---------------------------------------------------------------------------
-- 3. add_program_week / add_program_day
-- ---------------------------------------------------------------------------

-- Appends a week of 7 rest days, Day 1 to Day 7, after the program's last
-- week. Returns the new week's id.
create function public.add_program_week(p_program_id uuid)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_week_id uuid := gen_random_uuid();
  v_week_number integer;
  v_week_position integer;
  v_after integer;
begin
  if v_user_id is null then
    raise exception 'not_authenticated: sign in required' using errcode = 'P0001';
  end if;
  if not exists (
    select 1 from public.programs p where p.id = p_program_id and p.user_id = v_user_id
  ) then
    raise exception 'not_found: program % is not available', p_program_id using errcode = 'P0001';
  end if;

  select coalesce(max(w.week_number), 0) + 1, coalesce(max(w.position), 0) + 1
  into v_week_number, v_week_position
  from public.program_weeks w where w.program_id = p_program_id;

  select coalesce(max(d.position), -1) into v_after
  from public.program_days d where d.program_id = p_program_id;

  insert into public.program_weeks (id, program_id, user_id, week_number, position)
  values (v_week_id, p_program_id, v_user_id, v_week_number, v_week_position);

  insert into public.program_days (
    program_id, program_week_id, user_id, day_number, title, is_rest_day, position
  )
  select p_program_id, v_week_id, v_user_id, n, 'Day ' || n, true, v_after + n
  from generate_series(1, 7) n;

  return v_week_id;
end;
$$;
revoke execute on function public.add_program_week(uuid) from public, anon;
grant execute on function public.add_program_week(uuid) to authenticated;

-- Adds one day at the end of a week; the trigger refuses it in a full week.
-- Its position goes right after the week's last day (later weeks' days move
-- up one), so the global order still follows the weeks. Returns the day's id.
create function public.add_program_day(p_week_id uuid, p_title text, p_is_rest_day boolean)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_week public.program_weeks%rowtype;
  v_after integer;
  v_day_id uuid := gen_random_uuid();
begin
  if v_user_id is null then
    raise exception 'not_authenticated: sign in required' using errcode = 'P0001';
  end if;
  if nullif(trim(p_title), '') is null then
    raise exception 'invalid_argument: a day needs a title' using errcode = 'P0001';
  end if;

  select * into v_week from public.program_weeks w
  where w.id = p_week_id and w.user_id = v_user_id;
  if not found then
    raise exception 'not_found: week % is not available', p_week_id using errcode = 'P0001';
  end if;

  -- Same placement as copy_program_day: after the week's last day, or after
  -- the last day of the weeks before it when the week is empty.
  select coalesce(max(d.position), -1) into v_after
  from public.program_days d
  join public.program_weeks w on w.id = d.program_week_id
  where d.program_id = v_week.program_id
    and (w.id = v_week.id or w.week_number < v_week.week_number);

  perform public._shift_program_days(v_week.program_id, v_after, 1);

  insert into public.program_days (
    id, program_id, program_week_id, user_id, day_number, title, is_rest_day, position
  ) values (
    v_day_id, v_week.program_id, v_week.id, v_user_id,
    (select count(*) + 1 from public.program_days d where d.program_week_id = v_week.id),
    trim(p_title), coalesce(p_is_rest_day, false), v_after + 1
  );

  return v_day_id;
end;
$$;
revoke execute on function public.add_program_day(uuid, text, boolean) from public, anon;
grant execute on function public.add_program_day(uuid, text, boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. start_program: weeks are calendar weeks
-- ---------------------------------------------------------------------------

-- Newest definition: 20261116015735_add_set_type.sql. Only the day loop's
-- query and date change.
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
  -- program-plan.md Section 12.3. Each week is 7 calendar days, empty weeks
  -- included: a day lands on start + 7 × week index + its place in the week
  -- (both 0-based, by position), so a short week leaves the rest of its
  -- calendar week free. Matches Program.fromJson's dayOffset client-side.
  for v_day in
    select pd.*,
      wk.week_index * 7
        + (row_number() over (partition by pd.program_week_id order by pd.position) - 1)::integer
        as day_offset
    from public.program_days pd
    join (
      select pw.id, (row_number() over (order by pw.position, pw.week_number) - 1)::integer as week_index
      from public.program_weeks pw
      where pw.program_id = p_program_id
    ) wk on wk.id = pd.program_week_id
    where pd.program_id = p_program_id
    order by wk.week_index, pd.position
  loop
    insert into public.workouts (
      user_id, title, date, notes, program_instance_id, program_day_id,
      is_copy, is_imported, copied_from_user_id, copied_from_display_name, copied_from_program_id
    )
    values (
      v_user_id,
      v_day.title,
      p_start_date + v_day.day_offset,
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
