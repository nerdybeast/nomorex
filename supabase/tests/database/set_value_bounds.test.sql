-- Set values no lifter could mean are refused by the database (#36), not only
-- by the app's steppers: clients write to PostgREST directly. Each rejection
-- names the constraint it expects, so a different check firing first (e.g.
-- the weight-mode one) can't make a test pass by accident. Runs as the seeded
-- a@a.com, through RLS, the way a hand-made request would arrive.
--
--   supabase test db        # local stack only; never --linked
begin;
create extension if not exists pgtap with schema extensions;
select plan(25);

-- ---------------------------------------------------------------------------
-- Fixtures, written as superuser so ids are known up front.
-- ---------------------------------------------------------------------------

create temp table t on commit drop as
select (select id from auth.users where email = 'a@a.com') as owner,
       (select id from public.exercises where name = 'Back Squat' and is_predefined limit 1) as squat,
       '00000000-0000-4000-8000-000000000a04'::uuid as pe_id,
       '00000000-0000-4000-8000-000000000a06'::uuid as we_id;
grant select on t to authenticated;

select isnt((select owner from t), null, 'seeded user a@a.com exists');

insert into public.programs (id, user_id, name)
select '00000000-0000-4000-8000-000000000a01'::uuid, owner, 'pgTAP bounds program' from t;
insert into public.program_weeks (id, program_id, user_id, week_number, position)
select '00000000-0000-4000-8000-000000000a02'::uuid, '00000000-0000-4000-8000-000000000a01'::uuid, owner, 1, 0 from t;
insert into public.program_days (id, program_id, program_week_id, user_id, day_number, title, position)
select '00000000-0000-4000-8000-000000000a03'::uuid, '00000000-0000-4000-8000-000000000a01'::uuid,
       '00000000-0000-4000-8000-000000000a02'::uuid, owner, 1, 'Day 1', 0 from t;
insert into public.program_exercises (id, program_day_id, user_id, exercise_id, position)
select pe_id, '00000000-0000-4000-8000-000000000a03'::uuid, owner, squat, 0 from t;

insert into public.workouts (id, user_id, title, date)
select '00000000-0000-4000-8000-000000000a05'::uuid, owner, 'pgTAP bounds workout', current_date from t;
insert into public.workout_exercises (id, workout_id, user_id, exercise_id, position)
select we_id, '00000000-0000-4000-8000-000000000a05'::uuid, owner, squat, 0 from t;

select set_config('request.jwt.claims',
  json_build_object('sub', (select owner from t), 'role', 'authenticated')::text, true);
set local role authenticated;

-- ---------------------------------------------------------------------------
-- program_sets
-- ---------------------------------------------------------------------------

select throws_like(
  $$ insert into public.program_sets (program_exercise_id, user_id, position, target_reps, weight_mode, absolute_weight_kg)
     select pe_id, auth.uid(), 1, 0, 'absolute', 100 from t $$,
  '%program_sets_target_reps_positive%', 'program set: 0 reps is rejected');
select throws_like(
  $$ insert into public.program_sets (program_exercise_id, user_id, position, target_reps, weight_mode, absolute_weight_kg)
     select pe_id, auth.uid(), 1, -3, 'absolute', 100 from t $$,
  '%program_sets_target_reps_positive%', 'program set: negative reps are rejected');
select throws_like(
  $$ insert into public.program_sets (program_exercise_id, user_id, position, target_reps, weight_mode, percentage)
     select pe_id, auth.uid(), 1, 5, 'percentage', 0 from t $$,
  '%program_sets_percentage_bounds%', 'program set: 0% is rejected');
select throws_like(
  $$ insert into public.program_sets (program_exercise_id, user_id, position, target_reps, weight_mode, percentage)
     select pe_id, auth.uid(), 1, 5, 'percentage', -10 from t $$,
  '%program_sets_percentage_bounds%', 'program set: a negative percentage is rejected');
select throws_like(
  $$ insert into public.program_sets (program_exercise_id, user_id, position, target_reps, weight_mode, percentage)
     select pe_id, auth.uid(), 1, 5, 'percentage', 900 from t $$,
  '%program_sets_percentage_bounds%', 'program set: 900% is rejected');
select throws_like(
  $$ insert into public.program_sets (program_exercise_id, user_id, position, target_reps, weight_mode, percentage, percentage_max)
     select pe_id, auth.uid(), 1, 5, 'percentage', 150, 250 from t $$,
  '%program_sets_percentage_bounds%', 'program set: a percentage range topping out above 200% is rejected');
select throws_like(
  $$ insert into public.program_sets (program_exercise_id, user_id, position, target_reps, weight_mode, absolute_weight_kg)
     select pe_id, auth.uid(), 1, 5, 'absolute', -20 from t $$,
  '%program_sets_absolute_weight_nonnegative%', 'program set: a negative load is rejected');

select lives_ok(
  $$ insert into public.program_sets (program_exercise_id, user_id, position, target_reps, target_reps_max, weight_mode, percentage, percentage_max)
     select pe_id, auth.uid(), 2, 1, 3, 'percentage', 0.5, 200 from t $$,
  'program set: 1 rep and the %1RM edges (0.5% and 200%) are accepted');
select lives_ok(
  $$ insert into public.program_sets (program_exercise_id, user_id, position, target_reps, weight_mode, absolute_weight_kg)
     select pe_id, auth.uid(), 3, 5, 'absolute', 0 from t $$,
  'program set: a 0 kg load is accepted');
select lives_ok(
  $$ insert into public.program_sets (program_exercise_id, user_id, position, weight_mode)
     select pe_id, auth.uid(), 4, 'open' from t $$,
  'program set: an open set with no reps prescribed is accepted');

-- ---------------------------------------------------------------------------
-- workout_sets: the same prescription rules
-- ---------------------------------------------------------------------------

select throws_like(
  $$ insert into public.workout_sets (workout_exercise_id, user_id, position, target_reps, weight_mode, absolute_weight_kg)
     select we_id, auth.uid(), 1, 0, 'absolute', 100 from t $$,
  '%workout_sets_target_reps_positive%', 'workout set: 0 reps is rejected');
select throws_like(
  $$ insert into public.workout_sets (workout_exercise_id, user_id, position, target_reps, weight_mode, percentage)
     select we_id, auth.uid(), 1, 5, 'percentage', 0 from t $$,
  '%workout_sets_percentage_bounds%', 'workout set: 0% is rejected');
select throws_like(
  $$ insert into public.workout_sets (workout_exercise_id, user_id, position, target_reps, weight_mode, percentage)
     select we_id, auth.uid(), 1, 5, 'percentage', 900 from t $$,
  '%workout_sets_percentage_bounds%', 'workout set: 900% is rejected');
select throws_like(
  $$ insert into public.workout_sets (workout_exercise_id, user_id, position, target_reps, weight_mode, percentage, percentage_max)
     select we_id, auth.uid(), 1, 5, 'percentage', 150, 250 from t $$,
  '%workout_sets_percentage_bounds%', 'workout set: a percentage range topping out above 200% is rejected');
select throws_like(
  $$ insert into public.workout_sets (workout_exercise_id, user_id, position, target_reps, weight_mode, absolute_weight_kg)
     select we_id, auth.uid(), 1, 5, 'absolute', -20 from t $$,
  '%workout_sets_absolute_weight_nonnegative%', 'workout set: a negative load is rejected');

-- ---------------------------------------------------------------------------
-- workout_sets: logged results
-- ---------------------------------------------------------------------------

select throws_like(
  $$ insert into public.workout_sets (workout_exercise_id, user_id, position, target_reps, weight_mode, actual_weight_kg)
     select we_id, auth.uid(), 1, 5, 'open', -5 from t $$,
  '%workout_sets_actual_weight_nonnegative%', 'workout set: a negative logged weight is rejected');
select throws_like(
  $$ insert into public.workout_sets (workout_exercise_id, user_id, position, target_reps, weight_mode, absolute_weight_kg, actual_reps)
     select we_id, auth.uid(), 1, 5, 'absolute', 100, -1 from t $$,
  '%workout_sets_actual_reps_nonnegative%', 'workout set: negative logged reps are rejected');

select lives_ok(
  $$ insert into public.workout_sets (workout_exercise_id, user_id, position, target_reps, weight_mode, absolute_weight_kg, actual_reps, actual_weight_kg)
     select we_id, auth.uid(), 2, 5, 'absolute', 0, 0, 0 from t $$,
  'workout set: a 0 kg load and a missed set logged as 0 reps at 0 kg are accepted');
select lives_ok(
  $$ insert into public.workout_sets (workout_exercise_id, user_id, position, target_reps, weight_mode, percentage)
     select we_id, auth.uid(), 3, 1, 'percentage', 110 from t $$,
  'workout set: a supramaximal 110% single is accepted');

-- An update is checked too, not just an insert.
select throws_like(
  $$ update public.workout_sets set actual_reps = -2
     where workout_exercise_id = (select we_id from t) and position = 2 $$,
  '%workout_sets_actual_reps_nonnegative%', 'workout set: logging negative reps on an existing set is rejected');
select throws_like(
  $$ update public.program_sets set percentage = 900
     where program_exercise_id = (select pe_id from t) and position = 2 $$,
  '%program_sets_percentage_bounds%', 'program set: editing an existing set to 900% is rejected');

-- ---------------------------------------------------------------------------
-- The constraints are validated, not left NOT VALID (which would skip old rows).
-- ---------------------------------------------------------------------------

reset role;

select is(
  (select count(*)::int from pg_constraint
   where conname in ('program_sets_target_reps_positive', 'program_sets_percentage_bounds',
                     'program_sets_absolute_weight_nonnegative', 'workout_sets_target_reps_positive',
                     'workout_sets_percentage_bounds', 'workout_sets_absolute_weight_nonnegative',
                     'workout_sets_actual_weight_nonnegative', 'workout_sets_actual_reps_nonnegative')
     and convalidated),
  8, 'all eight new set constraints exist and are validated');

-- personal_bests already had these from the original schema; keep them covered.
select throws_like(
  $$ insert into public.personal_bests (user_id, exercise_id, weight_kg, reps, date)
     select owner, squat, 100, 0, current_date from t $$,
  '%personal_bests_reps_check%', 'personal best: 0 reps is rejected');
select throws_like(
  $$ insert into public.personal_bests (user_id, exercise_id, weight_kg, reps, date)
     select owner, squat, 0, 1, current_date from t $$,
  '%personal_bests_weight_kg_check%', 'personal best: a 0 kg PR is rejected');

select * from finish();
rollback;
