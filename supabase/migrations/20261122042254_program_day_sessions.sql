-- A program day holds up to 3 sessions, each its own workout (#175).
--
-- Until now a program_day was both a calendar slot and exactly one workout,
-- so two-a-days (AM/PM) couldn't be programmed: the AI import merged them
-- into one day. A day stays the calendar slot (title, rest day, notes, its
-- place in a 7-day week, which sets its date); its exercises now hang off a
-- session:
--
--   programs -> program_weeks -> program_days -> program_sessions
--            -> program_exercises -> program_sets
--
--   1. program_sessions: title and notes (both optional), position within the
--      day, at most 3 per day (trigger, `day_full`). Every day gets one.
--   2. program_exercises.program_session_id. program_day_id stays, as a
--      denormalized copy of the session's day (like program_days.program_id),
--      so the public-read policy, copy_program's exercise mapping and the app
--      already deployed keep working. A BEFORE trigger fills whichever of the
--      two is missing (an older client sends only the day: the exercise goes
--      to the day's first session, created if the day has none); an AFTER
--      trigger refuses a session from another day.
--   3. workouts.program_session_id: start_program materializes one workout per
--      session, all on the day's date. program_day_id stays as it was.
--   4. Every function that creates days or exercises carries sessions:
--      start_program, copy_program, _copy_program_day_contents (duplicate week,
--      duplicate/copy day), add_program_week, add_program_day and the AI
--      import's ai_import_create_program / ai_import_place_notes.
--   5. New editor RPCs: add_program_session, duplicate_program_session,
--      reorder_program_sessions. A session is renamed or deleted directly.
--
-- Additive for the app already deployed: it reads exercises through
-- program_day_id and writes them with only that, which the trigger handles.

-- ---------------------------------------------------------------------------
-- 1. program_sessions
-- ---------------------------------------------------------------------------

create table public.program_sessions (
  id              uuid primary key default gen_random_uuid(),
  program_day_id  uuid not null references public.program_days(id) on delete cascade,
  user_id         uuid not null references auth.users(id) on delete cascade,
  title           text, -- optional ("AM"); the app shows "Session N" without one
  notes           text,
  position        integer not null, -- order within the day
  created_at      timestamptz not null default now(),
  unique (program_day_id, position)
);

alter table public.program_sessions enable row level security;
create index idx_program_sessions_user_id on public.program_sessions (user_id);

-- One SELECT policy, as 20260813033442_merge_permissive_select_policies.sql
-- did for the other program tables: own rows, or a public program's.
create policy program_sessions_select on public.program_sessions
  for select to authenticated
  using (
    (select auth.uid()) = user_id
    or exists (
      select 1 from public.program_days pd
      join public.programs p on p.id = pd.program_id
      where pd.id = program_sessions.program_day_id and p.is_public = true
    )
  );
create policy program_sessions_insert on public.program_sessions
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy program_sessions_update on public.program_sessions
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy program_sessions_delete on public.program_sessions
  for delete to authenticated using ((select auth.uid()) = user_id);

create trigger check_program_day_owner
  after insert or update of program_day_id, user_id on public.program_sessions
  for each row execute function public.check_parent_owner('program_days', 'program_day_id');

-- Same shape as enforce_program_week_day_limit: AFTER ROW so a bulk insert is
-- counted whole, and a lock on the day so two concurrent adds count in turn.
create function public.enforce_program_day_session_limit()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  perform 1 from public.program_days d where d.id = new.program_day_id for update;
  if (select count(*) from public.program_sessions s where s.program_day_id = new.program_day_id) > 3 then
    raise exception 'day_full: a day has at most 3 sessions' using errcode = 'P0001';
  end if;
  return null;
end;
$$;
revoke execute on function public.enforce_program_day_session_limit() from public, anon;

create trigger program_sessions_day_session_limit
  after insert or update of program_day_id on public.program_sessions
  for each row execute function public.enforce_program_day_session_limit();

-- Every existing day gets its one session.
insert into public.program_sessions (program_day_id, user_id, position)
select d.id, d.user_id, 0 from public.program_days d;

-- ---------------------------------------------------------------------------
-- 2. program_exercises.program_session_id
-- ---------------------------------------------------------------------------

alter table public.program_exercises
  add column program_session_id uuid references public.program_sessions(id) on delete cascade;

update public.program_exercises pe
set program_session_id = s.id
from public.program_sessions s
where s.program_day_id = pe.program_day_id;

alter table public.program_exercises alter column program_session_id set not null;
create index idx_program_exercises_program_session_id on public.program_exercises (program_session_id);

create trigger check_program_session_owner
  after insert or update of program_session_id, user_id on public.program_exercises
  for each row execute function public.check_parent_owner('program_sessions', 'program_session_id');

-- Fills whichever of program_day_id / program_session_id is missing. Lookups
-- only run when one is missing, which only a single-row client insert does:
-- the functions below always send both (a data-modifying CTE couldn't see a
-- session inserted by a sibling CTE).
create or replace function public.program_exercises_fill_session()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    if new.program_session_id is distinct from old.program_session_id
       and new.program_day_id is not distinct from old.program_day_id then
      select s.program_day_id into new.program_day_id
      from public.program_sessions s where s.id = new.program_session_id;
    end if;
    return new;
  end if;

  if new.program_session_id is null and new.program_day_id is not null then
    select s.id into new.program_session_id
    from public.program_sessions s
    where s.program_day_id = new.program_day_id
    order by s.position
    limit 1;
    if new.program_session_id is null and exists (
      select 1 from public.program_days d where d.id = new.program_day_id
    ) then
      insert into public.program_sessions (program_day_id, user_id, position)
      values (new.program_day_id, new.user_id, 0)
      returning id into new.program_session_id;
    end if;
    -- Another user's private day reads as missing: refuse it as
    -- check_parent_owner would, not with a bare not-null error. A day
    -- inserted earlier in the same statement (a data-modifying CTE) reads as
    -- missing too; such a statement must insert the sessions itself and pass
    -- program_session_id, as copy_program does.
    if new.program_session_id is null then
      raise exception 'parent_not_owned: program_days.program_day_id must belong to the same user as the program_exercises (a day inserted in the same statement needs its program_session_id passed)'
        using errcode = '42501';
    end if;
  elsif new.program_day_id is null and new.program_session_id is not null then
    select s.program_day_id into new.program_day_id
    from public.program_sessions s where s.id = new.program_session_id;
    if new.program_day_id is null then
      raise exception 'parent_not_owned: program_sessions.program_session_id must belong to the same user as the program_exercises'
        using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;
revoke execute on function public.program_exercises_fill_session() from public, anon;

create trigger program_exercises_fill_session
  before insert or update of program_day_id, program_session_id on public.program_exercises
  for each row execute function public.program_exercises_fill_session();

-- AFTER ROW, like check_parent_owner, so it sees sessions inserted earlier in
-- the same statement.
create function public.check_program_exercise_session_day()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.program_sessions s
    where s.id = new.program_session_id and s.program_day_id = new.program_day_id
  ) then
    raise exception 'session_mismatch: the session belongs to another day' using errcode = 'P0001';
  end if;
  return null;
end;
$$;
revoke execute on function public.check_program_exercise_session_day() from public, anon;

create trigger check_program_exercise_session_day
  after insert or update of program_day_id, program_session_id on public.program_exercises
  for each row execute function public.check_program_exercise_session_day();

-- ---------------------------------------------------------------------------
-- 3. workouts.program_session_id
-- ---------------------------------------------------------------------------

alter table public.workouts
  add column program_session_id uuid references public.program_sessions(id) on delete set null;
create index idx_workouts_program_session_id on public.workouts (program_session_id);

create trigger check_program_session_owner
  after insert or update of program_session_id, user_id on public.workouts
  for each row execute function public.check_parent_owner('program_sessions', 'program_session_id');

-- Runs already started: each day had one workout, now its day's one session.
update public.workouts w
set program_session_id = s.id
from public.program_sessions s
where s.program_day_id = w.program_day_id and w.program_session_id is null;

-- ---------------------------------------------------------------------------
-- 4. Functions that create days or exercises
-- ---------------------------------------------------------------------------

-- Copies one session's exercises and sets onto another session (of the
-- caller's own program). Shared by _copy_program_day_contents and
-- duplicate_program_session.
create function public._copy_program_session_contents(
  p_source_session_id uuid,
  p_target_session_id uuid,
  p_user_id uuid
) returns void
language sql
security invoker
set search_path = ''
as $$
  with tgt as (
    select s.program_day_id from public.program_sessions s where s.id = p_target_session_id
  ), src_ex as (
    select pe.*, gen_random_uuid() as new_id
    from public.program_exercises pe
    -- Only the caller's own rows: reading a public program's rows and
    -- re-inserting them would skip copy_program's attribution.
    where pe.program_session_id = p_source_session_id and pe.user_id = (select auth.uid())
  ), ins_ex as (
    insert into public.program_exercises (
      id, program_day_id, program_session_id, user_id, exercise_id, position, notes
    )
    select ex.new_id, tgt.program_day_id, p_target_session_id, p_user_id, ex.exercise_id, ex.position, ex.notes
    from src_ex ex cross join tgt
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
$$;
revoke execute on function public._copy_program_session_contents(uuid, uuid, uuid) from public, anon;
grant execute on function public._copy_program_session_contents(uuid, uuid, uuid) to authenticated;

-- Newest definition: 20261116015735_add_set_type.sql. Now copies the day's
-- sessions, each with its exercises and sets, onto the target day (which the
-- callers, duplicate_program_week and copy_program_day, create without any).
create or replace function public._copy_program_day_contents(
  p_source_day_id uuid,
  p_target_day_id uuid,
  p_user_id uuid
) returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_session public.program_sessions%rowtype;
  v_new_session_id uuid;
begin
  for v_session in
    select * from public.program_sessions s
    where s.program_day_id = p_source_day_id and s.user_id = (select auth.uid())
    order by s.position
  loop
    insert into public.program_sessions (program_day_id, user_id, title, notes, position)
    values (p_target_day_id, p_user_id, v_session.title, v_session.notes, v_session.position)
    returning id into v_new_session_id;
    perform public._copy_program_session_contents(v_session.id, v_new_session_id, p_user_id);
  end loop;
end;
$$;

-- Newest definition: 20261120061847_limit_program_weeks_to_seven_days.sql.
-- Each new day gets its one session.
create or replace function public.add_program_week(p_program_id uuid)
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

  insert into public.program_sessions (program_day_id, user_id, position)
  select d.id, v_user_id, 0 from public.program_days d where d.program_week_id = v_week_id;

  return v_week_id;
end;
$$;

-- Newest definition: 20261120061847_limit_program_weeks_to_seven_days.sql.
-- The new day gets its one session.
create or replace function public.add_program_day(p_week_id uuid, p_title text, p_is_rest_day boolean)
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

  insert into public.program_sessions (program_day_id, user_id, position)
  values (v_day_id, v_user_id, 0);

  return v_day_id;
end;
$$;

-- Newest definition: 20261120061847_limit_program_weeks_to_seven_days.sql.
-- One workout per session, all on the day's date; a day with no session
-- (never written by the app) still gets one empty workout, as every day did
-- before. A day with several sessions titles each "<day> · <session>", with
-- "Session N" for an untitled one; a single session keeps the day's title.
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
  v_session record;
  v_session_count integer;
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

  -- Each week is 7 calendar days, empty weeks included: a day lands on
  -- start + 7 × week index + its place in the week (both 0-based, by
  -- position). Matches Program.fromJson's dayOffset client-side.
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
    select count(*) into v_session_count
    from public.program_sessions ps where ps.program_day_id = v_day.id;

    for v_session in
      select s.id, s.title, s.notes, s.n
      from (
        select ps.id, ps.title, ps.notes,
          row_number() over (order by ps.position)::integer as n
        from public.program_sessions ps
        where ps.program_day_id = v_day.id
      ) s
      union all
      select null::uuid, null::text, null::text, 1
      where v_session_count = 0
      order by 4
    loop
      insert into public.workouts (
        user_id, title, date, notes, program_instance_id, program_day_id, program_session_id,
        is_copy, is_imported, copied_from_user_id, copied_from_display_name, copied_from_program_id
      )
      values (
        v_user_id,
        case when v_session_count > 1
          then v_day.title || ' · ' || coalesce(nullif(trim(v_session.title), ''), 'Session ' || v_session.n)
          else v_day.title
        end,
        p_start_date + v_day.day_offset,
        nullif(concat_ws(E'\n', nullif(trim(v_day.notes), ''), nullif(trim(v_session.notes), '')), ''),
        v_instance_id,
        v_day.id,
        v_session.id,
        v_program.is_copy,
        v_program.is_imported,
        v_program.copied_from_user_id,
        v_program.copied_from_display_name,
        v_program.copied_from_program_id
      )
      returning id into v_workout_id;

      if not v_day.is_rest_day and v_session.id is not null then
        for v_exercise in
          select pe.*
          from public.program_exercises pe
          where pe.program_session_id = v_session.id
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
  end loop;

  return v_instance_id;
end;
$function$;

-- Newest definition: 20261116015735_add_set_type.sql. Copies sessions
-- between days and exercises.
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
  ), src_ss as (
    select ss.*, gen_random_uuid() as new_id, dy.new_id as new_day_id
    from public.program_sessions ss
    join src_dy dy on dy.id = ss.program_day_id
  ), ins_ss as (
    insert into public.program_sessions (id, program_day_id, user_id, title, notes, position)
    select new_id, new_day_id, v_user_id, title, notes, position
    from src_ss
  ), src_ex as (
    select pe.*, gen_random_uuid() as new_id, ss.new_day_id, ss.new_id as new_session_id
    from public.program_exercises pe
    join src_ss ss on ss.id = pe.program_session_id
  ), ins_ex as (
    insert into public.program_exercises (
      id, program_day_id, program_session_id, user_id, exercise_id, position, notes
    )
    select new_id, new_day_id, new_session_id, v_user_id,
      (v_map ->> exercise_id::text)::uuid, position, notes
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

-- ---------------------------------------------------------------------------
-- AI import: a day's `sessions`
-- ---------------------------------------------------------------------------

-- A reviewed day's sessions: its `sessions` array (import schema 2), or else
-- one session holding the day's `exercises` (schema 1, stored by imports that
-- finished before this change and are still waiting for review).
create function public.ai_import_day_sessions(p_day jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select case
    when jsonb_typeof(p_day -> 'sessions') = 'array' and jsonb_array_length(p_day -> 'sessions') > 0
      then p_day -> 'sessions'
    else jsonb_build_array(jsonb_build_object('exercises', coalesce(p_day -> 'exercises', '[]'::jsonb)))
  end;
$$;
revoke execute on function public.ai_import_day_sessions(jsonb) from public, anon;
grant execute on function public.ai_import_day_sessions(jsonb) to authenticated;

-- A day's exercises across its sessions, in order. Notes are placed by an
-- exercise's index in this list, so "w.d.e" keys mean the same in both schemas.
create function public.ai_import_day_exercises(p_day jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select coalesce(jsonb_agg(e.value order by s.n, e.n), '[]'::jsonb)
  from jsonb_array_elements(public.ai_import_day_sessions(p_day)) with ordinality s(value, n)
  cross join lateral jsonb_array_elements(coalesce(s.value -> 'exercises', '[]'::jsonb))
    with ordinality e(value, n);
$$;
revoke execute on function public.ai_import_day_exercises(jsonb) from public, anon;
grant execute on function public.ai_import_day_exercises(jsonb) to authenticated;

-- Newest definition: 20261110001658_add_ai_import_accept.sql. Only the
-- exercise lookup changes: it reads the day's exercises across its sessions.
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
    from jsonb_array_elements(
      case when v_day is null then '[]'::jsonb else public.ai_import_day_exercises(v_days -> v_day) end
    ) with ordinality e(value, n)
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

-- Newest definition: 20261110001658_add_ai_import_accept.sql. Each day's
-- sessions (ai_import_day_sessions) become program_sessions, at most 3 (the
-- trigger refuses a 4th; normalize.ts never produces one). A day's position is
-- global across the program; start_program dates it from its week and its
-- place in the week.
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

-- Newest definition: 20261110001658_add_ai_import_accept.sql. A workout's
-- one day may now come as sessions (import schema 2): its exercises are read
-- across them, in order, as one workout.
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

-- ---------------------------------------------------------------------------
-- 5. Editor RPCs for sessions
-- ---------------------------------------------------------------------------

-- Appends a session to the end of a day; the trigger refuses a 4th
-- (`day_full`). Returns the new session's id.
create function public.add_program_session(p_day_id uuid, p_title text default null)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_id uuid;
begin
  if v_user_id is null then
    raise exception 'not_authenticated: sign in required' using errcode = 'P0001';
  end if;
  if not exists (
    select 1 from public.program_days d where d.id = p_day_id and d.user_id = v_user_id
  ) then
    raise exception 'not_found: day % is not available', p_day_id using errcode = 'P0001';
  end if;

  insert into public.program_sessions (program_day_id, user_id, title, position)
  values (
    p_day_id, v_user_id, nullif(trim(p_title), ''),
    (select coalesce(max(s.position), -1) + 1 from public.program_sessions s where s.program_day_id = p_day_id)
  )
  returning id into v_id;
  return v_id;
end;
$$;
revoke execute on function public.add_program_session(uuid, text) from public, anon;
grant execute on function public.add_program_session(uuid, text) to authenticated;

-- Inserts a copy of the session, with its exercises and sets, right after it;
-- later sessions of the day move down one. Returns the copy's id.
create function public.duplicate_program_session(p_session_id uuid)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_src public.program_sessions%rowtype;
  v_id uuid;
begin
  if v_user_id is null then
    raise exception 'not_authenticated: sign in required' using errcode = 'P0001';
  end if;
  select * into v_src from public.program_sessions s
  where s.id = p_session_id and s.user_id = v_user_id;
  if not found then
    raise exception 'not_found: session % is not available', p_session_id using errcode = 'P0001';
  end if;

  -- unique(program_day_id, position): negatives first.
  update public.program_sessions
  set position = -(position + 1) - 1
  where program_day_id = v_src.program_day_id and position > v_src.position;
  update public.program_sessions
  set position = -position - 1
  where program_day_id = v_src.program_day_id and position < 0;

  insert into public.program_sessions (program_day_id, user_id, title, notes, position)
  values (v_src.program_day_id, v_user_id, v_src.title, v_src.notes, v_src.position + 1)
  returning id into v_id;
  perform public._copy_program_session_contents(v_src.id, v_id, v_user_id);
  return v_id;
end;
$$;
revoke execute on function public.duplicate_program_session(uuid) from public, anon;
grant execute on function public.duplicate_program_session(uuid) to authenticated;

-- Puts a day's sessions in p_session_ids order (every session of the day,
-- once), numbered from 0.
create function public.reorder_program_sessions(p_day_id uuid, p_session_ids uuid[])
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
begin
  if v_user_id is null then
    raise exception 'not_authenticated: sign in required' using errcode = 'P0001';
  end if;
  if not exists (
    select 1 from public.program_days d where d.id = p_day_id and d.user_id = v_user_id
  ) then
    raise exception 'not_found: day % is not available', p_day_id using errcode = 'P0001';
  end if;
  if coalesce(cardinality(p_session_ids), 0) <> (
       select count(*) from public.program_sessions s where s.program_day_id = p_day_id
     )
     or (select count(distinct x) from unnest(p_session_ids) x) <> cardinality(p_session_ids)
     or exists (
       select 1 from unnest(p_session_ids) x
       where not exists (
         select 1 from public.program_sessions s where s.id = x and s.program_day_id = p_day_id
       )
     ) then
    raise exception 'invalid_argument: list every session of the day once' using errcode = 'P0001';
  end if;

  update public.program_sessions s
  set position = -o.n
  from unnest(p_session_ids) with ordinality o(id, n)
  where s.id = o.id;
  update public.program_sessions s
  set position = (o.n - 1)::integer
  from unnest(p_session_ids) with ordinality o(id, n)
  where s.id = o.id;
end;
$$;
revoke execute on function public.reorder_program_sessions(uuid, uuid[]) from public, anon;
grant execute on function public.reorder_program_sessions(uuid, uuid[]) to authenticated;

comment on column public.program_days.day_number is
  'The day''s place in its week (Day 1–7), display-only and not unique. Two sessions on one day are program_sessions, not two days.';
