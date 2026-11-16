-- replace_workout_set_group (#151) rewrites a run of identical consecutive
-- workout sets in place: later sets keep their order, every prescription
-- column (set_type included) is written, and the logging columns come back
-- at their defaults. Runs as the seeded a@a.com; the cross-user refusal is in
-- rls_rpcs.test.sql.
--
--   supabase test db        # local stack only; never --linked
begin;
create extension if not exists pgtap with schema extensions;
select plan(17);

-- ---------------------------------------------------------------------------
-- Fixtures, written as superuser with fixed ids.
--
-- Workout W: Back Squat (e1) with three 3 × 50 kg warm-ups, logged, then two
-- singles at 80% of Pull-Up; Pull-Up (e2) with three open sets.
-- ---------------------------------------------------------------------------

create temp table t on commit drop as
select (select id from auth.users where email = 'a@a.com') as a,
       (select id from public.exercises where name = 'Back Squat' and is_predefined limit 1) as squat,
       (select id from public.exercises where name = 'Pull-Up' and is_predefined limit 1) as pullup,
       '00000000-0000-4000-8000-00000000c000'::uuid as w,
       '00000000-0000-4000-8000-00000000c001'::uuid as e1,
       '00000000-0000-4000-8000-00000000c002'::uuid as e2;
grant select on t to authenticated;

insert into public.workouts (id, user_id, title, date)
select w, a, 'pgTAP set group workout', current_date from t;
insert into public.workout_exercises (id, workout_id, user_id, exercise_id, position)
select e1, w, a, squat, 0 from t
union all select e2, w, a, pullup, 1 from t;
insert into public.workout_sets (
  workout_exercise_id, user_id, position, target_reps, weight_mode, percentage, absolute_weight_kg,
  basis_exercise_id, set_type, completed, actual_reps, actual_rpe
)
select e1, a, 0, 3, 'absolute', null::numeric, 50::numeric, null::uuid, 'warmup', true, 3, 7::numeric from t
union all select e1, a, 1, 3, 'absolute', null, 50, null, 'warmup', true, 3, 7 from t
union all select e1, a, 2, 3, 'absolute', null, 50, null, 'warmup', false, null, null from t
union all select e1, a, 3, 1, 'percentage', 80, null, pullup, 'working', false, null, null from t
union all select e1, a, 4, 1, 'percentage', 80, null, pullup, 'working', false, null, null from t
union all select e2, a, 0, 8, 'open', null, null, null, 'working', false, null, null from t
union all select e2, a, 1, 8, 'open', null, null, null, 'working', false, null, null from t
union all select e2, a, 2, 8, 'open', null, null, null, 'working', false, null, null from t;

create temp table g on commit drop as
select (select array_agg(id order by position) from public.workout_sets
        where workout_exercise_id = (select e1 from t) and position < 3) as warmups,
       (select array_agg(id order by position) from public.workout_sets
        where workout_exercise_id = (select e1 from t) and position >= 3) as singles,
       (select array_agg(id order by position) from public.workout_sets
        where workout_exercise_id = (select e2 from t)) as pulls;
grant select on g to authenticated;

select set_config('request.jwt.claims', json_build_object('sub', (select a from t), 'role', 'authenticated')::text, true);
set local role authenticated;

-- ---------------------------------------------------------------------------
-- Rewriting a group
-- ---------------------------------------------------------------------------

select lives_ok(
  $$ select public.replace_workout_set_group((select warmups from g), 4,
       '{"target_reps": 5, "weight_mode": "absolute", "absolute_weight_kg": 60, "set_type": "warmup",
         "rpe_min": 6, "rpe_max": 7, "note": "fast"}'::jsonb) $$,
  'replaces three 3 × 50 kg warm-ups with four 5 × 60 kg');
select is(
  (select array_agg(target_reps || '@' || coalesce(absolute_weight_kg::text, percentage::text || '%')
                    order by position)
   from public.workout_sets where workout_exercise_id = (select e1 from t)),
  array['5@60', '5@60', '5@60', '5@60', '1@80%', '1@80%'],
  'the new group takes the old one''s place and later sets keep their order');
select is(
  (select array_agg(position order by position) from public.workout_sets where workout_exercise_id = (select e1 from t)),
  array[0, 1, 2, 3, 4, 5], 'positions stay distinct and contiguous');
select is(
  (select count(*)::int from public.workout_sets
   where workout_exercise_id = (select e1 from t) and target_reps = 5
     and set_type = 'warmup' and rpe_min = 6 and rpe_max = 7 and note = 'fast'),
  4, 'every prescription column is written, set type included');
select is(
  (select count(*)::int from public.workout_sets
   where workout_exercise_id = (select e1 from t) and target_reps = 5
     and (completed or actual_reps is not null or actual_rpe is not null or actual_weight_kg is not null)),
  0, 'the new sets carry no logged results');
select is(
  (select count(*)::int from public.workout_sets
   where workout_exercise_id = (select e1 from t) and target_reps = 5 and user_id = auth.uid()),
  4, 'the new sets belong to the caller');

select lives_ok(
  $$ select public.replace_workout_set_group((select singles from g), 3,
       jsonb_build_object('target_reps', 2, 'weight_mode', 'percentage', 'percentage', 85,
                          'basis_exercise_id', (select pullup from t))) $$,
  'grows the two singles to three doubles at 85%, keeping the basis lift');
select is(
  (select count(*)::int from public.workout_sets
   where workout_exercise_id = (select e1 from t) and percentage = 85
     and basis_exercise_id = (select pullup from t) and set_type = 'working'),
  3, 'a prescription that names no set type makes working sets');

select lives_ok(
  $$ select public.replace_workout_set_group(
       (select array_agg(id order by position) from public.workout_sets
        where workout_exercise_id = (select e1 from t) and percentage = 85), 0, '{}'::jsonb) $$,
  'a count of 0 removes the group');
select is(
  (select count(*)::int from public.workout_sets where workout_exercise_id = (select e1 from t)), 4,
  'only the removed group''s sets are gone');

-- ---------------------------------------------------------------------------
-- Refusals
-- ---------------------------------------------------------------------------

select throws_like(
  $$ select public.replace_workout_set_group((select warmups from g), 1, '{}'::jsonb) $$,
  'not_found:%', 'sets that no longer exist are refused');
select throws_like(
  $$ select public.replace_workout_set_group(array[]::uuid[], 1, '{}'::jsonb) $$,
  'invalid_argument:%', 'an empty group is refused');
select throws_like(
  $$ select public.replace_workout_set_group((select pulls from g), -1, '{}'::jsonb) $$,
  'invalid_argument:%', 'a negative count is refused');
select throws_like(
  $$ select public.replace_workout_set_group(array[(select pulls[1] from g), (select pulls[3] from g)], 2,
       '{"target_reps": 8, "weight_mode": "open"}'::jsonb) $$,
  'invalid_group:%', 'sets with another set between them are refused');
select throws_like(
  $$ select public.replace_workout_set_group(
       array[(select pulls[1] from g),
             (select id from public.workout_sets where workout_exercise_id = (select e1 from t) limit 1)],
       2, '{"target_reps": 8, "weight_mode": "open"}'::jsonb) $$,
  'invalid_group:%', 'sets from two exercises are refused');
select throws_ok(
  $$ select public.replace_workout_set_group((select pulls from g), 3,
       '{"target_reps": 8, "weight_mode": "open", "set_type": "dropset"}'::jsonb) $$,
  '23514', null, 'a value the set constraints reject fails the whole call');
select is(
  (select count(*)::int from public.workout_sets where workout_exercise_id = (select e2 from t)), 3,
  'a failed call leaves the group as it was');

select * from finish();
rollback;
