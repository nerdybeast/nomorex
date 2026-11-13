-- duplicate_program_week, copy_program_day and replace_program_set_group
-- (#127) keep a program's week numbers and global day positions unique and
-- in order, copy every prescription column, and replace a set group in
-- place. Runs as the seeded a@a.com; cross-user refusals are in
-- rls_rpcs.test.sql.
--
--   supabase test db        # local stack only; never --linked
begin;
create extension if not exists pgtap with schema extensions;
select plan(27);

-- ---------------------------------------------------------------------------
-- Fixtures, written as superuser with fixed ids.
--
-- Program P: Week 1 "Meso 1/4" (Day 1, Day 2), Week 2 (Day 3), Week 3 (empty).
-- Day 1 holds Back Squat with an absolute, a percentage-range and an open set.
-- Program Q: one week, for the cross-program refusal.
-- ---------------------------------------------------------------------------

create temp table t on commit drop as
select (select id from auth.users where email = 'a@a.com') as a,
       (select id from public.exercises where name = 'Back Squat' and is_predefined limit 1) as squat,
       (select id from public.exercises where name = 'Pull-Up' and is_predefined limit 1) as pullup,
       '00000000-0000-4000-8000-00000000f000'::uuid as p,
       '00000000-0000-4000-8000-00000000f001'::uuid as w1,
       '00000000-0000-4000-8000-00000000f002'::uuid as w2,
       '00000000-0000-4000-8000-00000000f003'::uuid as w3,
       '00000000-0000-4000-8000-00000000f011'::uuid as d1,
       '00000000-0000-4000-8000-00000000f012'::uuid as d2,
       '00000000-0000-4000-8000-00000000f013'::uuid as d3,
       '00000000-0000-4000-8000-00000000f021'::uuid as e1,
       '00000000-0000-4000-8000-00000000f022'::uuid as e2,
       '00000000-0000-4000-8000-00000000f023'::uuid as e3,
       '00000000-0000-4000-8000-00000000f100'::uuid as q,
       '00000000-0000-4000-8000-00000000f101'::uuid as qw;
grant select on t to authenticated;

insert into public.programs (id, user_id, name)
select p, a, 'pgTAP editor program' from t
union all select q, a, 'pgTAP other program' from t;
insert into public.program_weeks (id, program_id, user_id, week_number, label, notes, position)
select w1, p, a, 1, 'Meso 1/4', 'build', 0 from t
union all select w2, p, a, 2, null, null, 1 from t
union all select w3, p, a, 3, null, null, 2 from t
union all select qw, q, a, 1, null, null, 0 from t;
insert into public.program_days (id, program_id, program_week_id, user_id, day_number, title, is_rest_day, notes, position)
select d1, p, w1, a, 1, 'Day 1', false, 'heavy', 0 from t
union all select d2, p, w1, a, 2, 'Day 2', true, null, 1 from t
union all select d3, p, w2, a, 1, 'Day 3', false, null, 2 from t;
insert into public.program_exercises (id, program_day_id, user_id, exercise_id, position, notes)
select e1, d1, a, squat, 0, 'pause 2s' from t
union all select e2, d3, a, squat, 0, null from t
union all select e3, d3, a, pullup, 1, null from t;
insert into public.program_sets (
  program_exercise_id, user_id, position, target_reps, target_reps_max, weight_mode,
  percentage, percentage_max, absolute_weight_kg, rpe_min, rpe_max, basis_exercise_id, note
)
select e1, a, 0, 5, null, 'absolute', null, null, 100, null, null, null, null from t
union all select e1, a, 1, 7, 9, 'percentage', 67, 72.5, null, 6, 7, pullup, 'smooth' from t
union all select e1, a, 2, 10, null, 'open', null, null, null, null, null, null, null from t
-- e2: three 3 × 50 kg, then two 1 @ 80%.
union all select e2, a, 0, 3, null, 'absolute', null, null, 50, null, null, null, null from t
union all select e2, a, 1, 3, null, 'absolute', null, null, 50, null, null, null, null from t
union all select e2, a, 2, 3, null, 'absolute', null, null, 50, null, null, null, null from t
union all select e2, a, 3, 1, null, 'percentage', 80, null, null, null, null, null, null from t
union all select e2, a, 4, 1, null, 'percentage', 80, null, null, null, null, null, null from t
-- e3: three sets for the "not next to each other" refusal.
union all select e3, a, 0, 8, null, 'open', null, null, null, null, null, null, null from t
union all select e3, a, 1, 8, null, 'open', null, null, null, null, null, null, null from t
union all select e3, a, 2, 8, null, 'open', null, null, null, null, null, null, null from t;

-- Every day of P in order: "week_number:title", so one comparison checks both
-- the global day order and which week each day is in.
create temp view day_order as
select string_agg(w.week_number || ':' || d.title, ', ' order by d.position) as v
from public.program_days d join public.program_weeks w on w.id = d.program_week_id
where d.program_id = (select p from t);
grant select on day_order to authenticated;

-- One set's prescription as text, for comparing copies column by column.
create temp view set_rx as
select s.program_exercise_id, s.position, s.id,
       row(s.target_reps, s.target_reps_max, s.weight_mode, s.percentage, s.percentage_max,
           s.absolute_weight_kg, s.rpe_min, s.rpe_max, s.basis_exercise_id, s.note)::text as rx
from public.program_sets s;
grant select on set_rx to authenticated;

select set_config('request.jwt.claims', json_build_object('sub', (select a from t), 'role', 'authenticated')::text, true);
set local role authenticated;

-- ---------------------------------------------------------------------------
-- duplicate_program_week
-- ---------------------------------------------------------------------------

create temp table dup on commit drop as
select public.duplicate_program_week((select w1 from t)) as week_id;

select is((select week_number from public.program_weeks where id = (select week_id from dup)), 2,
  'the copy of Week 1 becomes Week 2');
select is((select label from public.program_weeks where id = (select week_id from dup)), 'Meso 1/4 (copy)',
  'the copy''s label says it is a copy');
select is((select notes from public.program_weeks where id = (select week_id from dup)), 'build',
  'the week''s notes are copied');
select is(
  (select array_agg(week_number order by week_number) from public.program_weeks where program_id = (select p from t)),
  array[1, 2, 3, 4], 'later weeks move up one, and week numbers stay unique');
select is((select week_number from public.program_weeks where id = (select w2 from t)), 3,
  'the old Week 2 is now Week 3');
select is((select v from day_order), '1:Day 1, 1:Day 2, 2:Day 1, 2:Day 2, 3:Day 3',
  'the copied days sit right after the original week, before later weeks'' days');
select is(
  (select count(distinct position)::int from public.program_days where program_id = (select p from t)),
  (select count(*)::int from public.program_days where program_id = (select p from t)),
  'day positions stay unique');
select is(
  (select row(d.day_number, d.is_rest_day, d.notes)::text from public.program_days d
   where d.program_week_id = (select week_id from dup) and d.title = 'Day 2'),
  row(2, true, null::text)::text, 'day number, rest day and notes are copied');
select is(
  (select pe.notes from public.program_exercises pe
   join public.program_days d on d.id = pe.program_day_id
   where d.program_week_id = (select week_id from dup)),
  'pause 2s', 'exercise notes are copied');
select results_eq(
  $$ select r.rx from set_rx r
     join public.program_exercises pe on pe.id = r.program_exercise_id
     join public.program_days d on d.id = pe.program_day_id
     where d.program_week_id = (select week_id from dup) order by r.position $$,
  $$ select rx from set_rx where program_exercise_id = (select e1 from t) order by position $$,
  'every prescription column of every set is copied, in order');
select is(
  (select count(*)::int from public.program_days where program_week_id = (select w1 from t)), 2,
  'the original week keeps its days');

-- ---------------------------------------------------------------------------
-- copy_program_day
-- ---------------------------------------------------------------------------

-- Day 1 into the empty last week (old Week 3, now 4) and back into Week 1.
create temp table cp on commit drop as
select public.copy_program_day((select d1 from t), array[(select w3 from t), (select w1 from t)]) as ids;

select is((select cardinality(ids) from cp), 2, 'one new day per target week');
select is((select v from day_order),
  '1:Day 1, 1:Day 2, 1:Day 1, 2:Day 1, 2:Day 2, 3:Day 3, 4:Day 1',
  'each copy goes at the end of its week, an empty week included');
select is(
  (select day_number from public.program_days where id = (select ids[2] from cp)), 3,
  'the copy is numbered after the week''s other days');
select is(
  (select count(*)::int from public.program_sets s
   join public.program_exercises pe on pe.id = s.program_exercise_id
   where pe.program_day_id = (select ids[1] from cp)), 3,
  'the day''s exercises and sets are copied');
select throws_like(
  $$ select public.copy_program_day((select d1 from t), array[(select qw from t)]) $$,
  'not_found:%', 'refuses a week of another program');
select throws_like(
  $$ select public.copy_program_day((select d1 from t), array[]::uuid[]) $$,
  'invalid_argument:%', 'refuses an empty list of weeks');

-- ---------------------------------------------------------------------------
-- replace_program_set_group
-- ---------------------------------------------------------------------------

create temp table g on commit drop as
select (select array_agg(id order by position) from public.program_sets
        where program_exercise_id = (select e2 from t) and position < 3) as fifties,
       (select array_agg(id order by position) from public.program_sets
        where program_exercise_id = (select e2 from t) and position >= 3) as eighties,
       (select array_agg(id order by position) from public.program_sets
        where program_exercise_id = (select e3 from t)) as pulls;

select lives_ok(
  $$ select public.replace_program_set_group((select fifties from g), 5,
       '{"target_reps": 5, "weight_mode": "absolute", "absolute_weight_kg": 60}'::jsonb) $$,
  'replaces three 3 × 50 kg with five 5 × 60 kg');
select is(
  (select array_agg(target_reps || '@' || coalesce(absolute_weight_kg::text, percentage::text || '%')
                    order by position)
   from public.program_sets where program_exercise_id = (select e2 from t)),
  array['5@60', '5@60', '5@60', '5@60', '5@60', '1@80%', '1@80%'],
  'the new group takes the old one''s place and later sets keep their order');
select is(
  (select count(distinct position)::int from public.program_sets where program_exercise_id = (select e2 from t)), 7,
  'set positions stay distinct');
select lives_ok(
  $$ select public.replace_program_set_group((select eighties from g), 0, '{}'::jsonb) $$,
  'a count of 0 removes the group');
select is(
  (select count(*)::int from public.program_sets where program_exercise_id = (select e2 from t)), 5,
  'only the removed group''s sets are gone');
select throws_ok(
  $$ select public.replace_program_set_group((select fifties from g), 1, '{}'::jsonb) $$,
  'P0001', null, 'sets that no longer exist are refused');
select throws_like(
  $$ select public.replace_program_set_group(array[(select pulls[1] from g), (select pulls[3] from g)], 2,
       '{"target_reps": 8, "weight_mode": "open"}'::jsonb) $$,
  'invalid_group:%', 'sets with another set between them are refused');
select throws_like(
  $$ select public.replace_program_set_group(
       array[(select pulls[1] from g), (select id from public.program_sets where program_exercise_id = (select e1 from t) limit 1)],
       2, '{"target_reps": 8, "weight_mode": "open"}'::jsonb) $$,
  'invalid_group:%', 'sets from two exercises are refused');
select throws_ok(
  $$ select public.replace_program_set_group((select pulls from g), 3,
       '{"target_reps": 0, "weight_mode": "open"}'::jsonb) $$,
  '23514', null, 'a value the set constraints reject fails the whole call');
select is(
  (select count(*)::int from public.program_sets where program_exercise_id = (select e3 from t)), 3,
  'a failed call leaves the group as it was');

select * from finish();
rollback;
