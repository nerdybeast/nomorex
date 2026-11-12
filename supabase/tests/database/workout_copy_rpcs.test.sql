-- duplicate_workout, finish_workout and repeat_workout (#35) build a workout
-- out of one of the caller's own in one transaction, copy only the
-- prescription, and take copy attribution from the source row. Runs as the
-- seeded a@a.com; cross-user refusals are in rls_rpcs.test.sql.
--
--   supabase test db        # local stack only; never --linked
begin;
create extension if not exists pgtap with schema extensions;
select plan(31);

-- ---------------------------------------------------------------------------
-- Fixtures, written as superuser with fixed ids.
-- ---------------------------------------------------------------------------

create temp table t on commit drop as
select (select id from auth.users where email = 'a@a.com') as a,
       (select id from auth.users where email = 'b@b.com') as b,
       (select id from public.exercises where name = 'Back Squat' and is_predefined limit 1) as squat,
       (select id from public.exercises where name = 'Pull-Up' and is_predefined limit 1) as pullup,
       '00000000-0000-4000-8000-00000000e001'::uuid as own,        -- finished, logged, own group
       '00000000-0000-4000-8000-00000000e002'::uuid as copied,     -- a Community copy
       '00000000-0000-4000-8000-00000000e003'::uuid as imported,   -- an AI import
       '00000000-0000-4000-8000-00000000e004'::uuid as live,       -- in progress, no sibling
       '00000000-0000-4000-8000-00000000e005'::uuid as prog_day,   -- in progress, from a program run
       '00000000-0000-4000-8000-00000000e006'::uuid as archived,
       '00000000-0000-4000-8000-00000000e007'::uuid as boom,       -- its second set fails to copy
       '00000000-0000-4000-8000-00000000e008'::uuid as live2,      -- in progress, with a not-started sibling
       '00000000-0000-4000-8000-00000000e009'::uuid as next2,
       '00000000-0000-4000-8000-00000000e0a8'::uuid as group2;
grant select on t to authenticated;

insert into public.programs (id, user_id, name)
select '00000000-0000-4000-8000-00000000e100'::uuid, a, 'pgTAP copy rpc program' from t;
insert into public.program_instances (id, program_id, user_id, started_at)
select '00000000-0000-4000-8000-00000000e101'::uuid, '00000000-0000-4000-8000-00000000e100'::uuid, a, current_date from t;

-- The public workout of b's that "copied" was copied from.
insert into public.workouts (id, user_id, title, date, is_public)
select '00000000-0000-4000-8000-00000000e0ff'::uuid, b, 'pgTAP b''s original', current_date, true from t;

insert into public.workouts (
  id, user_id, title, date, notes, status, started_at, finished_at,
  is_copy, is_imported, copied_from_user_id, copied_from_display_name, copied_from_workout_id,
  is_archived, archived_at, program_instance_id, workout_group_id
)
select own, a, 'pgTAP own', current_date - 3, 'cue: brace', 'finished', now(), now(),
       false, false, null::uuid, null, null::uuid, false, null::timestamptz, null::uuid, gen_random_uuid() from t
union all select copied, a, 'pgTAP copied', current_date, null, 'not_started', null, null,
       true, false, b, 'BeastModeB', '00000000-0000-4000-8000-00000000e0ff'::uuid, false, null, null, gen_random_uuid() from t
union all select imported, a, 'pgTAP imported', current_date, null, 'not_started', null, null,
       true, true, null, null, null, false, null, null, gen_random_uuid() from t
union all select live, a, 'pgTAP live', current_date, null, 'in_progress', now(), null,
       false, false, null, null, null, false, null, null, gen_random_uuid() from t
union all select prog_day, a, 'pgTAP program day', current_date, null, 'in_progress', now(), null,
       false, false, null, null, null, false, null, '00000000-0000-4000-8000-00000000e101'::uuid, gen_random_uuid() from t
union all select archived, a, 'pgTAP archived', current_date, null, 'finished', now(), now(),
       false, false, null, null, null, true, now(), null, gen_random_uuid() from t
union all select boom, a, 'pgTAP boom', current_date, null, 'finished', now(), now(),
       false, false, null, null, null, false, null, null, gen_random_uuid() from t
union all select live2, a, 'pgTAP live2', current_date, null, 'in_progress', now(), null,
       false, false, null, null, null, false, null, null, group2 from t
union all select next2, a, 'pgTAP live2', current_date, null, 'not_started', null, null,
       false, false, null, null, null, false, null, null, group2 from t;

-- "own": Back Squat 7-9 @ 67-72.5% of Pull-Up, RPE 6-7, logged; Pull-Up open load, logged.
insert into public.workout_exercises (id, workout_id, user_id, exercise_id, position, notes)
select '00000000-0000-4000-8000-00000000e011'::uuid, own, a, squat, 0, 'pause 2s' from t
union all select '00000000-0000-4000-8000-00000000e012'::uuid, own, a, pullup, 1, null from t
union all select '00000000-0000-4000-8000-00000000e041'::uuid, live, a, squat, 0, null from t
union all select '00000000-0000-4000-8000-00000000e071'::uuid, boom, a, squat, 0, null from t;
insert into public.workout_sets (
  workout_exercise_id, user_id, position, target_reps, target_reps_max, weight_mode,
  percentage, percentage_max, absolute_weight_kg, rpe_min, rpe_max, basis_exercise_id, note,
  completed, actual_reps, actual_weight_kg, actual_rpe
)
select '00000000-0000-4000-8000-00000000e011'::uuid, a, 0, 7, 9, 'percentage',
       67, 72.5, null::numeric, 6, 7, pullup, 'smooth', true, 8, null::numeric, 7.5 from t
union all select '00000000-0000-4000-8000-00000000e011'::uuid, a, 1, 5, null, 'absolute',
       null, null, 100, null, null, null, null, false, null, null, null from t
union all select '00000000-0000-4000-8000-00000000e012'::uuid, a, 0, 8, 10, 'open',
       null, null, null, 8, null, null, null, true, 9, 40, 8 from t
union all select '00000000-0000-4000-8000-00000000e041'::uuid, a, 0, 5, null, 'absolute',
       null, null, 80, null, null, null, null, true, 5, 80, null from t
union all select '00000000-0000-4000-8000-00000000e071'::uuid, a, 0, 5, null, 'absolute',
       null, null, 80, null, null, null, null, false, null, null, null from t
union all select '00000000-0000-4000-8000-00000000e071'::uuid, a, 1, 5, null, 'absolute',
       null, null, 80, null, null, null, 'boom', false, null, null, null from t;

-- Makes copying "boom"'s second set fail, after its workout row and first set
-- have already been inserted, so a partial copy would be visible.
create function pg_temp.fail_on_boom() returns trigger language plpgsql as $$
begin
  if new.note = 'boom' and new.workout_exercise_id <> '00000000-0000-4000-8000-00000000e071'::uuid then
    raise exception 'injected failure';
  end if;
  return new;
end;
$$;
create trigger fail_on_boom before insert on public.workout_sets
  for each row execute function pg_temp.fail_on_boom();

-- The prescription of a workout's sets, comparable across copies.
create function pg_temp.prescription(p_workout_id uuid) returns setof text language sql as $$
  select row(we.position, we.exercise_id, we.notes, ws.position, ws.target_reps, ws.target_reps_max,
             ws.weight_mode, ws.percentage, ws.percentage_max, ws.absolute_weight_kg,
             ws.rpe_min, ws.rpe_max, ws.basis_exercise_id, ws.note)::text
  from public.workout_exercises we
  join public.workout_sets ws on ws.workout_exercise_id = we.id
  where we.workout_id = p_workout_id
  order by we.position, ws.position
$$;
-- Logged results on a workout's sets (should be none on anything copied).
create function pg_temp.logged(p_workout_id uuid) returns int language sql as $$
  select count(*)::int
  from public.workout_exercises we
  join public.workout_sets ws on ws.workout_exercise_id = we.id
  where we.workout_id = p_workout_id
    and (ws.completed or ws.actual_reps is not null or ws.actual_weight_kg is not null or ws.actual_rpe is not null)
$$;

select set_config('request.jwt.claims', json_build_object('sub', (select a from t), 'role', 'authenticated')::text, true);
set local role authenticated;

-- ---------------------------------------------------------------------------
-- duplicate_workout
-- ---------------------------------------------------------------------------

create temp table r on commit drop as
select public.duplicate_workout((select own from t), current_date) as dup,
       public.duplicate_workout((select copied from t), current_date) as dup_copied,
       public.duplicate_workout((select imported from t), current_date) as dup_imported;

select is((select title from public.workouts where id = (select dup from r)), 'pgTAP own (copy)',
  'duplicate is titled "<title> (copy)"');
select is((select row(user_id, date, notes, status)::text from public.workouts where id = (select dup from r)),
  (select row(a, current_date, 'cue: brace', 'not_started')::text from t),
  'duplicate is the caller''s, dated today, keeps the notes, not started');
select isnt((select workout_group_id from public.workouts where id = (select dup from r)),
  (select workout_group_id from public.workouts where id = (select own from t)),
  'duplicate starts its own group');
select results_eq(
  $$ select * from pg_temp.prescription((select dup from r)) $$,
  $$ select * from pg_temp.prescription((select own from t)) $$,
  'duplicate keeps every exercise and set prescription: ranges, RPE, open load, basis, notes');
select is(pg_temp.logged((select dup from r)), 0, 'duplicate carries no logged results');
select is((select is_copy from public.workouts where id = (select dup from r)), false,
  'duplicating your own workout is not a copy');

select is(
  (select row(is_copy, is_imported, copied_from_user_id, copied_from_display_name, copied_from_workout_id)::text
   from public.workouts where id = (select dup_copied from r)),
  (select row(true, false, b, 'BeastModeB', '00000000-0000-4000-8000-00000000e0ff'::uuid)::text from t),
  'duplicating a Community copy stays a copy with the same attribution');
select is(
  (select row(is_copy, is_imported)::text from public.workouts where id = (select dup_imported from r)),
  row(true, true)::text,
  'duplicating an import stays an import');
select throws_like(
  $$ update public.workouts set is_public = true where id = (select dup_copied from r) $$,
  '%', 'a duplicate of a copy can''t be made public');

select throws_like(
  $$ select public.duplicate_workout((select archived from t), current_date) $$,
  'archived:%', 'duplicate_workout refuses an archived workout');

-- ---------------------------------------------------------------------------
-- finish_workout
-- ---------------------------------------------------------------------------

create temp table f on commit drop as
select public.finish_workout((select live from t), 'felt good', current_date) as next_id;

select is((select row(status, session_notes)::text from public.workouts where id = (select live from t)),
  row('finished', 'felt good')::text, 'finish_workout finishes the session with its notes');
select isnt((select next_id from f), null, 'finish_workout returns the next instance');
select is(
  (select row(workout_group_id, status, title)::text from public.workouts where id = (select next_id from f)),
  (select row(workout_group_id, 'not_started', title)::text from public.workouts where id = (select live from t)),
  'the next instance is a not-started session of the same group');
select results_eq(
  $$ select * from pg_temp.prescription((select next_id from f)) $$,
  $$ select * from pg_temp.prescription((select live from t)) $$,
  'the next instance copies the exercises and sets');
select is(pg_temp.logged((select next_id from f)), 0, 'the next instance carries no logged results');

select is(public.finish_workout((select live2 from t), null, current_date), null,
  'finish_workout makes no next instance when a live sibling exists');
select is((select count(*)::int from public.workouts where workout_group_id = (select group2 from t)), 2,
  'so the group still has just the finished session and its one sibling');

select is(public.finish_workout((select prog_day from t), null, current_date), null,
  'finish_workout makes no next instance for a program day');
select is((select status from public.workouts where id = (select prog_day from t)), 'finished',
  'but still finishes the program day');

-- ---------------------------------------------------------------------------
-- repeat_workout
-- ---------------------------------------------------------------------------

select is(public.repeat_workout((select live from t), current_date), (select next_id from f),
  'repeat_workout reuses the not-started sibling');
select is((select status from public.workouts where id = (select next_id from f)), 'in_progress',
  'and starts it');
select throws_like(
  $$ select public.repeat_workout((select live from t), current_date) $$,
  'already_in_progress:%', 'repeat_workout refuses while a session of the group is live');

create temp table rp on commit drop as
select public.repeat_workout((select own from t), current_date) as id;
select is(
  (select row(workout_group_id, status, title, is_copy)::text from public.workouts where id = (select id from rp)),
  (select row(workout_group_id, 'in_progress', title, false)::text from public.workouts where id = (select own from t)),
  'with no sibling, repeat_workout creates a session in the same group and starts it');
select results_eq(
  $$ select * from pg_temp.prescription((select id from rp)) $$,
  $$ select * from pg_temp.prescription((select own from t)) $$,
  'the repeated session copies the prescription');
select is(pg_temp.logged((select id from rp)), 0, 'the repeated session carries no logged results');

select throws_like(
  $$ select public.repeat_workout((select archived from t), current_date) $$,
  'archived:%', 'repeat_workout refuses an archived workout');
-- Finish the copy first so repeating it creates a new row rather than
-- reusing the copy itself.
update public.workouts set status = 'finished', started_at = now(), finished_at = now()
where id = (select copied from t);
create temp table rc on commit drop as
select public.repeat_workout((select copied from t), current_date) as id;
select is(
  (select row(is_copy, copied_from_display_name)::text from public.workouts
   where id = (select id from rc) and id <> (select copied from t)),
  row(true, 'BeastModeB')::text,
  'repeating a copy stays a copy');

-- ---------------------------------------------------------------------------
-- All or nothing
-- ---------------------------------------------------------------------------

create temp table before_fail on commit drop as
select (select count(*) from public.workouts) as w, (select count(*) from public.workout_exercises) as we,
       (select count(*) from public.workout_sets) as ws;

select throws_like(
  $$ select public.duplicate_workout((select boom from t), current_date) $$,
  '%injected failure%', 'a failure while copying sets fails duplicate_workout');
select throws_like(
  $$ select public.repeat_workout((select boom from t), current_date) $$,
  '%injected failure%', 'and fails repeat_workout');
select is(
  (select row((select count(*) from public.workouts), (select count(*) from public.workout_exercises),
              (select count(*) from public.workout_sets))::text),
  (select row(w, we, ws)::text from before_fail),
  'neither left a workout, exercise or set behind');
select is((select status from public.workouts where id = (select boom from t)), 'finished',
  'and the source workout is untouched');

select * from finish();
rollback;
