-- A program day holds 1–3 sessions, each its own workout
-- (20261122042254_program_day_sessions.sql): the cap, every day-creating path
-- giving a day its session, the trigger that keeps program_exercises'
-- day and session in step, the session RPCs, start_program's one workout per
-- session, and the copies carrying sessions. Runs as the seeded a@a.com;
-- cross-user refusals are in rls_rpcs.test.sql.
--
--   supabase test db        # local stack only; never --linked
begin;
create extension if not exists pgtap with schema extensions;
select plan(31);

-- Program P, Week 1: Day 1 (training, sessions AM and an untitled one),
-- Day 2 (one session), Day 3 (no session at all, as no app path writes).
create temp table t on commit drop as
select (select id from auth.users where email = 'a@a.com') as a,
       (select id from auth.users where email = 'b@b.com') as b,
       (select id from public.exercises where is_predefined and name = 'Back Squat' limit 1) as ex,
       '00000000-0000-4000-8000-00000000e800'::uuid as p,
       '00000000-0000-4000-8000-00000000e801'::uuid as w1,
       '00000000-0000-4000-8000-00000000e802'::uuid as d1,
       '00000000-0000-4000-8000-00000000e803'::uuid as d2,
       '00000000-0000-4000-8000-00000000e804'::uuid as d3,
       '00000000-0000-4000-8000-00000000e805'::uuid as s1,
       '00000000-0000-4000-8000-00000000e806'::uuid as s2,
       '00000000-0000-4000-8000-00000000e807'::uuid as s3;
grant select on t to authenticated;

insert into public.programs (id, user_id, name) select p, a, 'pgTAP sessions' from t;
insert into public.program_weeks (id, program_id, user_id, week_number, position) select w1, p, a, 1, 0 from t;
insert into public.program_days (id, program_id, program_week_id, user_id, day_number, title, notes, position)
select d1, p, w1, a, 1, 'Day 1', 'Belt on', 0 from t
union all select d2, p, w1, a, 2, 'Day 2', null, 1 from t
union all select d3, p, w1, a, 3, 'Day 3', null, 2 from t;
insert into public.program_sessions (id, program_day_id, user_id, title, notes, position)
select s1, d1, a, 'AM', 'Fasted', 0 from t
union all select s2, d1, a, null, null, 1 from t
union all select s3, d2, a, null, null, 0 from t;

select set_config('request.jwt.claims', json_build_object('sub', (select a from t), 'role', 'authenticated')::text, true);
set local role authenticated;

-- program_exercises: either column fills the other.
insert into public.program_exercises (program_session_id, user_id, exercise_id, position)
select s2, a, ex, 0 from t;
select is(
  (select program_day_id from public.program_exercises where program_session_id = (select s2 from t)),
  (select d1 from t), 'an exercise given only its session gets the session''s day');

insert into public.program_exercises (program_day_id, user_id, exercise_id, position)
select d1, a, ex, 0 from t;
select is(
  (select count(*)::int from public.program_exercises where program_session_id = (select s1 from t)),
  1, 'an exercise given only its day (an older app) goes to the day''s first session');

insert into public.program_exercises (program_day_id, user_id, exercise_id, position)
select d3, a, ex, 0 from t;
select is(
  (select count(*)::int from public.program_sessions where program_day_id = (select d3 from t)),
  1, 'a day with no session gets one when an exercise is added by day');
select is(
  (select program_session_id from public.program_exercises where program_day_id = (select d3 from t)),
  (select id from public.program_sessions where program_day_id = (select d3 from t)),
  '... and the exercise goes to it');

select throws_like(
  $$ insert into public.program_exercises (program_day_id, program_session_id, user_id, exercise_id, position)
     select d2, s1, a, ex, 5 from t $$,
  'session_mismatch:%', 'a session from another day is refused');
select throws_like(
  $$ update public.program_exercises set program_day_id = (select d2 from t)
     where program_session_id = (select s2 from t) $$,
  'session_mismatch:%', 'moving only the day away from its session is refused');

update public.program_exercises set program_session_id = (select s1 from t)
where program_session_id = (select s2 from t);
select is(
  (select count(*)::int from public.program_exercises where program_session_id = (select s1 from t)),
  2, 'moving an exercise to another session of the day is fine');
update public.program_exercises set program_session_id = (select s3 from t)
where id = (select id from public.program_exercises where program_session_id = (select s1 from t) order by created_at desc, id limit 1);
select is(
  (select program_day_id from public.program_exercises where program_session_id = (select s3 from t)),
  (select d2 from t), 'moving an exercise to another day''s session moves its day too');

-- The cap: a 4th session is refused however it arrives.
select lives_ok(
  $$ select public.add_program_session((select d1 from t), 'PM') $$,
  'add_program_session adds a 3rd session');
select is(
  (select string_agg(coalesce(title, '-') || ':' || position, ', ' order by position)
   from public.program_sessions where program_day_id = (select d1 from t)),
  'AM:0, -:1, PM:2', 'add_program_session appends after the others');
select throws_like(
  $$ select public.add_program_session((select d1 from t), null) $$,
  'day_full:%', 'add_program_session refuses a 4th session');
select throws_like(
  $$ insert into public.program_sessions (program_day_id, user_id, position) select d1, a, 9 from t $$,
  'day_full:%', 'a direct insert of a 4th session is refused');
select throws_like(
  $$ select public.duplicate_program_session((select s1 from t)) $$,
  'day_full:%', 'duplicating a session of a full day is refused');

-- reorder_program_sessions
select lives_ok(
  $$ select public.reorder_program_sessions((select d1 from t),
       array(select id from public.program_sessions where program_day_id = (select d1 from t) order by position desc)) $$,
  'reorder_program_sessions takes every session of the day');
select is(
  (select string_agg(coalesce(title, '-'), ', ' order by position)
   from public.program_sessions where program_day_id = (select d1 from t)),
  'PM, -, AM', 'reorder_program_sessions puts them in the given order');
select throws_like(
  $$ select public.reorder_program_sessions((select d1 from t), array[(select s1 from t)]) $$,
  'invalid_argument:%', 'reorder_program_sessions needs every session of the day');

-- duplicate_program_session: right after it, with its exercises and sets.
delete from public.program_sessions
where program_day_id = (select d1 from t) and title = 'PM';
insert into public.program_sets (program_exercise_id, user_id, position, target_reps, weight_mode, absolute_weight_kg)
select pe.id, t.a, 0, 5, 'absolute', 100
from public.program_exercises pe, t where pe.program_session_id = t.s1;
create temp table dup on commit drop as select public.duplicate_program_session((select s1 from t)) as id;
select is(
  (select string_agg(coalesce(title, '-'), ', ' order by position)
   from public.program_sessions where program_day_id = (select d1 from t)),
  '-, AM, AM', 'duplicate_program_session inserts the copy right after it');
select is(
  (select count(*)::int from public.program_sets ps
   join public.program_exercises pe on pe.id = ps.program_exercise_id
   where pe.program_session_id = (select id from dup)),
  1, 'duplicate_program_session copies the exercises and sets');
delete from public.program_sessions where id = (select id from dup);

-- Every path that creates a day gives it its session.
create temp table nw on commit drop as select public.add_program_week((select p from t)) as id;
select is(
  (select count(*)::int from public.program_days d
   where d.program_week_id = (select id from nw)
     and (select count(*) from public.program_sessions s where s.program_day_id = d.id) = 1),
  7, 'add_program_week gives each of its 7 days one session');
create temp table nd on commit drop as select public.add_program_day((select w1 from t), 'Day 4', false) as id;
select is(
  (select count(*)::int from public.program_sessions where program_day_id = (select id from nd)),
  1, 'add_program_day gives the day one session');
create temp table cd on commit drop as
select unnest(public.copy_program_day((select d1 from t), array[(select w1 from t)])) as id;
select is(
  (select string_agg(coalesce(s.title, '-') || ':' ||
     (select count(*) from public.program_exercises pe where pe.program_session_id = s.id), ', ' order by s.position)
   from public.program_sessions s where s.program_day_id = (select id from cd)),
  (select string_agg(coalesce(s.title, '-') || ':' ||
     (select count(*) from public.program_exercises pe where pe.program_session_id = s.id), ', ' order by s.position)
   from public.program_sessions s where s.program_day_id = (select d1 from t)),
  'copy_program_day copies the day''s sessions and their exercises');
delete from public.program_days where id = (select id from cd);
create temp table dw on commit drop as select public.duplicate_program_week((select w1 from t)) as id;
select is(
  (select count(*)::int from public.program_sessions s
   join public.program_days d on d.id = s.program_day_id where d.program_week_id = (select id from dw)),
  (select count(*)::int from public.program_sessions s
   join public.program_days d on d.id = s.program_day_id where d.program_week_id = (select w1 from t)),
  'duplicate_program_week copies every day''s sessions');
delete from public.program_weeks where id in ((select id from dw), (select id from nw));

-- start_program: one workout per session, all on the day's date.
-- Week 1 now: Day 1 (untitled, AM), Day 2, Day 3, Day 4.
create temp table run on commit drop as
select public.start_program((select p from t), '2026-11-16'::date) as id;
select is(
  (select string_agg(title || '@' || date, ', ' order by date, title)
   from public.workouts where program_instance_id = (select id from run)),
  'Day 1 · AM@2026-11-16, Day 1 · Session 1@2026-11-16, Day 2@2026-11-17, Day 3@2026-11-18, Day 4@2026-11-19',
  'start_program makes one workout per session, titled by session on a day with several');
select is(
  (select count(*)::int from public.workouts w
   join public.program_sessions s on s.id = w.program_session_id
   where w.program_instance_id = (select id from run) and s.program_day_id = w.program_day_id),
  5, 'each workout names its session and that session''s day');
select is(
  (select notes from public.workouts where program_instance_id = (select id from run) and title = 'Day 1 · AM'),
  E'Belt on\nFasted', 'a session''s workout carries the day''s notes, then the session''s');
select is(
  (select notes from public.workouts where program_instance_id = (select id from run) and title = 'Day 1 · Session 1'),
  'Belt on', 'a session without notes carries the day''s');
select is(
  (select count(*)::int from public.workout_exercises we
   join public.workouts w on w.id = we.workout_id
   where w.program_instance_id = (select id from run) and w.title = 'Day 1 · AM'),
  (select count(*)::int from public.program_exercises where program_session_id = (select s1 from t)),
  'a session''s workout holds that session''s exercises');

-- A day with no session still gets one empty workout.
delete from public.program_sessions where program_day_id = (select d3 from t);
create temp table run2 on commit drop as
select public.start_program((select p from t), '2026-12-07'::date) as id;
select is(
  (select count(*)::int from public.workouts
   where program_instance_id = (select id from run2) and program_day_id = (select d3 from t)
     and program_session_id is null),
  1, 'a day with no session materializes one workout');

-- copy_program carries sessions (as b, copying a's public program).
reset role;
update public.programs set is_public = true where id = (select p from t);
select set_config('request.jwt.claims', json_build_object('sub',
  (select id from auth.users where email = 'b@b.com'), 'role', 'authenticated')::text, true);
set local role authenticated;
create temp table cp on commit drop as
select (public.copy_program((select p from t)) ->> 'program_id')::uuid as id;
select is(
  (select string_agg(d.title || ':' || coalesce(s.title, '-'), ', ' order by d.position, s.position)
   from public.program_sessions s join public.program_days d on d.id = s.program_day_id
   where d.program_id = (select id from cp)),
  'Day 1:-, Day 1:AM, Day 2:-, Day 4:-',
  'copy_program copies every session, in order');
select is(
  (select count(*)::int from public.program_exercises pe
   join public.program_days d on d.id = pe.program_day_id
   join public.program_sessions s on s.id = pe.program_session_id and s.program_day_id = d.id
   where d.program_id = (select id from cp)),
  (select count(*)::int from public.program_exercises pe
   join public.program_days d on d.id = pe.program_day_id where d.program_id = (select p from t)),
  'copy_program puts every exercise in its copied session');
select is(
  (select count(*)::int from public.program_sessions s
   join public.program_days d on d.id = s.program_day_id
   where d.program_id = (select id from cp) and s.user_id <> (select b from t)),
  0, 'the copied sessions are the viewer''s');

select * from finish();
rollback;
