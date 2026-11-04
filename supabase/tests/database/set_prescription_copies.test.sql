-- The set prescription columns from 20261104040520 (rep/percentage ranges,
-- RPE, the 'open' weight mode) must survive every server-side path that
-- builds sets from other sets, and the CHECK constraints must reject
-- malformed values. Runs as the seeded a@a.com (author) and b@b.com (viewer).
--
--   supabase test db        # local stack only; never --linked
begin;
create extension if not exists pgtap with schema extensions;
select plan(18);

-- ---------------------------------------------------------------------------
-- Fixtures, written as superuser so ids are known up front.
-- ---------------------------------------------------------------------------

create temp table t on commit drop as
select (select id from auth.users where email = 'a@a.com') as author,
       (select id from auth.users where email = 'b@b.com') as viewer,
       (select id from public.exercises where name = 'Back Squat' and is_predefined limit 1) as squat,
       (select id from public.exercises where name = 'Pull-Up' and is_predefined limit 1) as pullup;
grant select on t to authenticated;

select isnt((select author from t), null, 'seeded author a@a.com exists');
select isnt((select viewer from t), null, 'seeded viewer b@b.com exists');

insert into public.programs (id, user_id, name, is_public)
select '00000000-0000-4000-8000-000000000001'::uuid, author, 'pgTAP prescription program', true from t;
insert into public.program_weeks (id, program_id, user_id, week_number, position)
select '00000000-0000-4000-8000-000000000002'::uuid, '00000000-0000-4000-8000-000000000001'::uuid, author, 1, 0 from t;
insert into public.program_days (id, program_id, program_week_id, user_id, day_number, title, position)
select '00000000-0000-4000-8000-000000000003'::uuid, '00000000-0000-4000-8000-000000000001'::uuid,
       '00000000-0000-4000-8000-000000000002'::uuid, author, 1, 'Day 1', 0 from t;
insert into public.program_exercises (id, program_day_id, user_id, exercise_id, position)
select '00000000-0000-4000-8000-000000000004'::uuid, '00000000-0000-4000-8000-000000000003'::uuid, author, squat, 0 from t
union all
select '00000000-0000-4000-8000-000000000005'::uuid, '00000000-0000-4000-8000-000000000003'::uuid, author, pullup, 1 from t;
-- "Squat 7-9 @ 67-72.5% RPE 6-7" and "Pull-Up 7-9, choose load, RPE 6-7".
insert into public.program_sets (
  program_exercise_id, user_id, position, target_reps, target_reps_max,
  weight_mode, percentage, percentage_max, rpe_min, rpe_max
)
select '00000000-0000-4000-8000-000000000004'::uuid, author, 0, 7, 9, 'percentage', 67, 72.5, 6, 7 from t
union all
select '00000000-0000-4000-8000-000000000005'::uuid, author, 0, 7, 9, 'open', null, null, 6, 7 from t;

-- A public standalone workout with a logged open set.
insert into public.workouts (id, user_id, title, date, is_public)
select '00000000-0000-4000-8000-000000000006'::uuid, author, 'pgTAP prescription workout', current_date, true from t;
insert into public.workout_exercises (id, workout_id, user_id, exercise_id, position)
select '00000000-0000-4000-8000-000000000007'::uuid, '00000000-0000-4000-8000-000000000006'::uuid, author, pullup, 0 from t;
insert into public.workout_sets (
  workout_exercise_id, user_id, position, target_reps, target_reps_max,
  weight_mode, rpe_min, rpe_max, actual_rpe, actual_reps, completed
)
select '00000000-0000-4000-8000-000000000007'::uuid, author, 0, 5, 8, 'open', 8, 9, 8.5, 7, true from t;

-- ---------------------------------------------------------------------------
-- start_program (as the author)
-- ---------------------------------------------------------------------------

select set_config('request.jwt.claims',
  json_build_object('sub', (select author from t), 'role', 'authenticated')::text, true);
set local role authenticated;

create temp table author_run on commit drop as
select public.start_program('00000000-0000-4000-8000-000000000001'::uuid, current_date) as instance_id;

select results_eq(
  $$ select ws.target_reps, ws.target_reps_max, ws.weight_mode, ws.percentage,
            ws.percentage_max, ws.rpe_min, ws.rpe_max
     from public.workout_sets ws
     join public.workout_exercises we on we.id = ws.workout_exercise_id
     join public.workouts w on w.id = we.workout_id
     where w.program_instance_id = (select instance_id from author_run)
     order by we.position $$,
  $$ values (7, 9, 'percentage', 67::numeric, 72.5::numeric, 6.0::numeric, 7.0::numeric),
            (7, 9, 'open', null, null, 6.0, 7.0) $$,
  'start_program carries rep/percentage ranges, RPE and open mode onto workout sets'
);

-- ---------------------------------------------------------------------------
-- copy_program / copy_workout (as the viewer)
-- ---------------------------------------------------------------------------

reset role;
select set_config('request.jwt.claims',
  json_build_object('sub', (select viewer from t), 'role', 'authenticated')::text, true);
set local role authenticated;

create temp table viewer_copy on commit drop as
select public.copy_program('00000000-0000-4000-8000-000000000001'::uuid, current_date) as result;

select results_eq(
  $$ select ps.target_reps, ps.target_reps_max, ps.weight_mode, ps.percentage,
            ps.percentage_max, ps.rpe_min, ps.rpe_max
     from public.program_sets ps
     join public.program_exercises pe on pe.id = ps.program_exercise_id
     join public.program_days pd on pd.id = pe.program_day_id
     where pd.program_id = ((select result from viewer_copy) ->> 'program_id')::uuid
     order by pe.position $$,
  $$ values (7, 9, 'percentage', 67::numeric, 72.5::numeric, 6.0::numeric, 7.0::numeric),
            (7, 9, 'open', null, null, 6.0, 7.0) $$,
  'copy_program carries the prescription onto the copied template'
);

select results_eq(
  $$ select ws.target_reps_max, ws.weight_mode, ws.percentage_max, ws.rpe_min, ws.rpe_max
     from public.workout_sets ws
     join public.workout_exercises we on we.id = ws.workout_exercise_id
     join public.workouts w on w.id = we.workout_id
     where w.program_instance_id = ((select result from viewer_copy) ->> 'instance_id')::uuid
     order by we.position $$,
  $$ values (9, 'percentage', 72.5::numeric, 6.0::numeric, 7.0::numeric),
            (9, 'open', null, 6.0, 7.0) $$,
  'starting the copied program carries the prescription onto workout sets'
);

create temp table viewer_workout on commit drop as
select public.copy_workout('00000000-0000-4000-8000-000000000006'::uuid, current_date) as id;

select results_eq(
  $$ select ws.target_reps, ws.target_reps_max, ws.weight_mode, ws.rpe_min, ws.rpe_max
     from public.workout_sets ws
     join public.workout_exercises we on we.id = ws.workout_exercise_id
     where we.workout_id = (select id from viewer_workout) $$,
  $$ values (5, 8, 'open', 8.0::numeric, 9.0::numeric) $$,
  'copy_workout carries the prescription'
);

select results_eq(
  $$ select ws.actual_rpe, ws.actual_reps, ws.completed
     from public.workout_sets ws
     join public.workout_exercises we on we.id = ws.workout_exercise_id
     where we.workout_id = (select id from viewer_workout) $$,
  $$ values (null::numeric, null::int, false) $$,
  'copy_workout does not copy logged results (actual_rpe, actual_reps, completed)'
);

-- ---------------------------------------------------------------------------
-- CHECK constraints (as the viewer, on their own copied rows)
-- ---------------------------------------------------------------------------

create temp table viewer_ids on commit drop as
select (select we.id from public.workout_exercises we
        where we.workout_id = (select id from viewer_workout) limit 1) as we_id,
       (select pe.id from public.program_exercises pe
        join public.program_days pd on pd.id = pe.program_day_id
        where pd.program_id = ((select result from viewer_copy) ->> 'program_id')::uuid
        limit 1) as pe_id;

select throws_ok(
  $$ insert into public.workout_sets (workout_exercise_id, user_id, position, target_reps, target_reps_max, weight_mode, absolute_weight_kg)
     select we_id, auth.uid(), 9, 9, 7, 'absolute', 100 from viewer_ids $$,
  '23514', null, 'a rep range top below its bottom is rejected');
select throws_ok(
  $$ insert into public.workout_sets (workout_exercise_id, user_id, position, target_reps_max, weight_mode, absolute_weight_kg)
     select we_id, auth.uid(), 9, 9, 'absolute', 100 from viewer_ids $$,
  '23514', null, 'a rep range top without a bottom is rejected');
select throws_ok(
  $$ insert into public.workout_sets (workout_exercise_id, user_id, position, target_reps, weight_mode, percentage, percentage_max)
     select we_id, auth.uid(), 9, 5, 'percentage', 80, 75 from viewer_ids $$,
  '23514', null, 'a percentage range top below its bottom is rejected');
select throws_ok(
  $$ insert into public.workout_sets (workout_exercise_id, user_id, position, target_reps, weight_mode, absolute_weight_kg, percentage_max)
     select we_id, auth.uid(), 9, 5, 'absolute', 100, 80 from viewer_ids $$,
  '23514', null, 'a percentage range on an absolute set is rejected');
select throws_ok(
  $$ insert into public.workout_sets (workout_exercise_id, user_id, position, target_reps, weight_mode, absolute_weight_kg)
     select we_id, auth.uid(), 9, 5, 'open', 100 from viewer_ids $$,
  '23514', null, 'an open set carrying a load is rejected');
select throws_ok(
  $$ insert into public.workout_sets (workout_exercise_id, user_id, position, target_reps, weight_mode, absolute_weight_kg, rpe_max)
     select we_id, auth.uid(), 9, 5, 'absolute', 100, 8 from viewer_ids $$,
  '23514', null, 'an RPE top without a bottom is rejected');
select throws_ok(
  $$ insert into public.workout_sets (workout_exercise_id, user_id, position, target_reps, weight_mode, absolute_weight_kg, rpe_min)
     select we_id, auth.uid(), 9, 5, 'absolute', 100, 11 from viewer_ids $$,
  '23514', null, 'an RPE above 10 is rejected');
select throws_ok(
  $$ insert into public.workout_sets (workout_exercise_id, user_id, position, target_reps, weight_mode, absolute_weight_kg, actual_rpe)
     select we_id, auth.uid(), 9, 5, 'absolute', 100, 0.5 from viewer_ids $$,
  '23514', null, 'a logged RPE below 1 is rejected');
select throws_ok(
  $$ insert into public.program_sets (program_exercise_id, user_id, position, target_reps, weight_mode)
     select pe_id, auth.uid(), 9, 5, 'bogus' from viewer_ids $$,
  '23514', null, 'an unknown weight mode is rejected on program sets');
select throws_ok(
  $$ insert into public.program_sets (program_exercise_id, user_id, position, target_reps, weight_mode, percentage, percentage_max)
     select pe_id, auth.uid(), 9, 5, 'percentage', 80, 75 from viewer_ids $$,
  '23514', null, 'a percentage range top below its bottom is rejected on program sets');

select lives_ok(
  $$ insert into public.workout_sets (workout_exercise_id, user_id, position, target_reps, target_reps_max, weight_mode, rpe_min, rpe_max)
     select we_id, auth.uid(), 9, 7, 9, 'open', 7.5, 8 from viewer_ids $$,
  'a well-formed open set with a rep range and half-step RPE is accepted');

select * from finish();
rollback;
