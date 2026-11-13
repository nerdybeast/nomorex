-- The server-side functions refuse to act on another user's content, and the
-- copy rules can't be undone from the client (#34).
--
-- Every function here is SECURITY INVOKER, so RLS applies inside it too; these
-- tests prove each one fails closed rather than relying on that by reading.
-- a@a.com is the author, b@b.com the other user.
--
--   supabase test db        # local stack only; never --linked
begin;
create extension if not exists pgtap with schema extensions;
select plan(27);

-- ---------------------------------------------------------------------------
-- Fixtures, written as superuser with fixed ids.
-- ---------------------------------------------------------------------------

create temp table u on commit drop as
select (select id from auth.users where email = 'a@a.com') as a,
       (select id from auth.users where email = 'b@b.com') as b,
       (select id from public.exercises where is_predefined limit 1) as predefined,
       '00000000-0000-4000-8000-00000000d001'::uuid as priv_workout,
       '00000000-0000-4000-8000-00000000d002'::uuid as pub_workout,
       '00000000-0000-4000-8000-00000000d003'::uuid as live_workout,     -- a's private, in progress
       '00000000-0000-4000-8000-00000000d010'::uuid as priv_program,
       '00000000-0000-4000-8000-00000000d020'::uuid as pub_program;
grant select on u to authenticated;

insert into public.workouts (id, user_id, title, date, is_public, status, started_at)
select priv_workout, a, 'pgTAP rpc private workout', current_date, false, 'not_started', null::timestamptz from u
union all select pub_workout, a, 'pgTAP rpc public workout', current_date, true, 'not_started', null::timestamptz from u
union all select live_workout, a, 'pgTAP rpc live workout', current_date, false, 'in_progress', now() from u;
insert into public.workout_exercises (workout_id, user_id, exercise_id, position)
select pub_workout, a, predefined, 0 from u;

insert into public.programs (id, user_id, name, is_public)
select priv_program, a, 'pgTAP rpc private program', false from u
union all select pub_program, a, 'pgTAP rpc public program', true from u;
insert into public.program_weeks (id, program_id, user_id, week_number, position)
select '00000000-0000-4000-8000-00000000d011'::uuid, priv_program, a, 1, 0 from u
union all select '00000000-0000-4000-8000-00000000d021'::uuid, pub_program, a, 1, 0 from u;
insert into public.program_days (program_id, program_week_id, user_id, day_number, title, position)
select priv_program, '00000000-0000-4000-8000-00000000d011'::uuid, a, 1, 'Day 1', 0 from u
union all select pub_program, '00000000-0000-4000-8000-00000000d021'::uuid, a, 1, 'Day 1', 0 from u;
insert into public.program_exercises (id, program_day_id, user_id, exercise_id, position)
select '00000000-0000-4000-8000-00000000d022'::uuid,
       (select id from public.program_days where program_week_id = '00000000-0000-4000-8000-00000000d021'::uuid),
       a, predefined, 0 from u;
insert into public.program_sets (id, program_exercise_id, user_id, position, target_reps, weight_mode)
select '00000000-0000-4000-8000-00000000d023'::uuid, '00000000-0000-4000-8000-00000000d022'::uuid, a, 0, 5, 'open' from u;

create temp table snapshot on commit drop as
select id, status, started_at, paused_at, finished_at, session_notes from public.workouts
where id in (select live_workout from u union all select pub_workout from u);

-- ---------------------------------------------------------------------------
-- As b@b.com: refused on a's private content
-- ---------------------------------------------------------------------------

select set_config('request.jwt.claims', json_build_object('sub', (select b from u), 'role', 'authenticated')::text, true);
set local role authenticated;

select throws_like(
  $$ select public.copy_workout((select priv_workout from u), current_date, false) $$,
  'not_found:%', 'copy_workout refuses a''s private workout');
select throws_like(
  $$ select public.copy_workout((select priv_workout from u), current_date, true) $$,
  'not_found:%', 'copy_workout with start refuses a''s private workout');
select throws_like(
  $$ select public.copy_program((select priv_program from u), null) $$,
  'not_found:%', 'copy_program refuses a''s private program');
select throws_like(
  $$ select public.copy_program((select priv_program from u), current_date) $$,
  'not_found:%', 'copy_program with a start date refuses a''s private program');
select throws_like(
  $$ select public.start_program((select priv_program from u), current_date) $$,
  '%not found for the current user%', 'start_program refuses a''s private program');
-- start_program runs your own programs; another user's public one goes through copy_program.
select throws_like(
  $$ select public.start_program((select pub_program from u), current_date) $$,
  '%not found for the current user%', 'start_program refuses a''s public program too');

-- Duplicate/repeat/finish work only on the caller's own workouts, public or not.
select throws_like(
  $$ select public.duplicate_workout((select pub_workout from u), current_date) $$,
  'not_found:%', 'duplicate_workout refuses a''s public workout');
select throws_like(
  $$ select public.repeat_workout((select priv_workout from u), current_date) $$,
  'not_found:%', 'repeat_workout refuses a''s workout');
select throws_like(
  $$ select public.finish_workout((select live_workout from u), 'b was here', current_date) $$,
  'not_found:%', 'finish_workout refuses a''s live workout');
select throws_like(
  $$ select public.copy_workout_tree((select pub_workout from u), (select priv_workout from u)) $$,
  'not_found:%', 'copy_workout_tree refuses a''s workouts');
select throws_like(
  $$ select public.new_workout_from((select pub_workout from u), 'stolen', current_date, null) $$,
  'not_found:%', 'new_workout_from refuses a''s workout');

-- The program editor's functions (#127) work only on the caller's own
-- programs, even where a's public program is readable.
select throws_like(
  $$ select public.duplicate_program_week('00000000-0000-4000-8000-00000000d021'::uuid) $$,
  'not_found:%', 'duplicate_program_week refuses a''s public week');
select throws_like(
  $$ select public.copy_program_day(
       (select id from public.program_days where program_week_id = '00000000-0000-4000-8000-00000000d021'::uuid),
       array['00000000-0000-4000-8000-00000000d021'::uuid]) $$,
  'not_found:%', 'copy_program_day refuses a''s public day');
select throws_like(
  $$ select public.replace_program_set_group(array['00000000-0000-4000-8000-00000000d023'::uuid], 3,
       '{"target_reps": 1, "weight_mode": "open"}'::jsonb) $$,
  'not_found:%', 'replace_program_set_group refuses a''s sets');

-- The session functions are filtered to the caller's rows, so on a's
-- workout they do nothing at all (checked as superuser below).
select lives_ok($$ select public.pause_workout_session((select live_workout from u)) $$,
  'pause_workout_session on a''s workout returns without error');
select public.resume_workout_session(live_workout) from u;
select public.finish_workout_session(live_workout, 'b was here') from u;
select public.discard_workout_session(live_workout) from u;
select public.start_workout_session(pub_workout) from u;
select public.finish_workout_session(pub_workout, 'b was here') from u;

-- ---------------------------------------------------------------------------
-- Copies of a's public content are b's own, and stay marked as copies
-- ---------------------------------------------------------------------------

create temp table copies on commit drop as
select public.copy_workout((select pub_workout from u), current_date, false) as workout_id,
       (public.copy_program((select pub_program from u), null) ->> 'program_id')::uuid as program_id;

select is((select user_id from public.workouts where id = (select workout_id from copies)), (select b from u),
  'a copied public workout belongs to b');
select is((select is_copy from public.workouts where id = (select workout_id from copies)), true,
  'a copied public workout is marked as a copy');
select is((select user_id from public.programs where id = (select program_id from copies)), (select b from u),
  'a copied public program belongs to b');

select throws_ok(
  $$ update public.workouts set is_public = true where id = (select workout_id from copies) $$,
  '23514', null, 'b cannot publish b''s copy of a''s workout');
select throws_ok(
  $$ update public.programs set is_public = true where id = (select program_id from copies) $$,
  '23514', null, 'b cannot publish b''s copy of a''s program');
select throws_like(
  $$ update public.workouts set is_copy = false where id = (select workout_id from copies) $$,
  'copy_is_permanent:%', 'b cannot un-mark b''s copy of a''s workout');
select throws_like(
  $$ update public.programs set is_copy = false where id = (select program_id from copies) $$,
  'copy_is_permanent:%', 'b cannot un-mark b''s copy of a''s program');

-- ---------------------------------------------------------------------------
-- As superuser: nothing b did touched a's rows
-- ---------------------------------------------------------------------------

reset role;

select is(
  (select row(w.status, w.started_at, w.paused_at, w.finished_at, w.session_notes)::text
   from public.workouts w where w.id = (select live_workout from u)),
  (select row(s.status, s.started_at, s.paused_at, s.finished_at, s.session_notes)::text
   from snapshot s where s.id = (select live_workout from u)),
  'b''s pause/resume/finish/discard left a''s live workout exactly as it was');
select is(
  (select row(w.status, w.started_at, w.finished_at, w.session_notes)::text
   from public.workouts w where w.id = (select pub_workout from u)),
  (select row(s.status, s.started_at, s.finished_at, s.session_notes)::text
   from snapshot s where s.id = (select pub_workout from u)),
  'b''s start/finish left a''s public workout exactly as it was');
select is(
  (select count(*)::int from public.program_instances where program_id in (select priv_program from u union all select pub_program from u)),
  0, 'no program run of a''s programs was created by b''s calls');
select is(
  (select row(
     (select count(*) from public.program_weeks where program_id = pub_program),
     (select count(*) from public.program_days where program_id = pub_program),
     (select string_agg(id::text || ':' || target_reps, ',') from public.program_sets
      where program_exercise_id = '00000000-0000-4000-8000-00000000d022'::uuid))::text from u),
  row(1::bigint, 1::bigint, '00000000-0000-4000-8000-00000000d023:5'::text)::text,
  'b''s program editor calls left a''s public program exactly as it was');
select is(
  (select count(*)::int from public.workouts
   where user_id = (select a from u) and id not in (select priv_workout from u union all select pub_workout from u union all select live_workout from u)),
  0, 'b''s calls created no workout owned by a');

select * from finish();
rollback;
