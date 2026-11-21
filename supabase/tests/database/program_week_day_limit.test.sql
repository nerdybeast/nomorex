-- A program week holds at most 7 days and takes 7 calendar days
-- (20261120061847_limit_program_weeks_to_seven_days.sql): the trigger refuses
-- an 8th day on every path, add_program_week adds 7 rest days, add_program_day
-- fills a short week, and start_program dates days by week and place in the
-- week. Runs as the seeded a@a.com; cross-user refusals are in
-- rls_rpcs.test.sql.
--
--   supabase test db        # local stack only; never --linked
begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

-- Program P: Week 1 holds 3 training days (Day 1–3), Week 2 is empty.
create temp table t on commit drop as
select (select id from auth.users where email = 'a@a.com') as a,
       '00000000-0000-4000-8000-00000000e700'::uuid as p,
       '00000000-0000-4000-8000-00000000e701'::uuid as w1,
       '00000000-0000-4000-8000-00000000e702'::uuid as w2;
grant select on t to authenticated;

insert into public.programs (id, user_id, name) select p, a, 'pgTAP week limit' from t;
insert into public.program_weeks (id, program_id, user_id, week_number, position)
select w1, p, a, 1, 0 from t union all select w2, p, a, 2, 1 from t;
insert into public.program_days (program_id, program_week_id, user_id, day_number, title, position)
select p, w1, a, n, 'Day ' || n, n - 1 from t, generate_series(1, 3) n;

select set_config('request.jwt.claims', json_build_object('sub', (select a from t), 'role', 'authenticated')::text, true);
set local role authenticated;

-- add_program_week: 7 rest days, Day 1–7, after every existing day.
create temp table nw on commit drop as select public.add_program_week((select p from t)) as id;
select is(
  (select week_number from public.program_weeks where id = (select id from nw)), 3,
  'add_program_week appends Week 3');
select is(
  (select string_agg(title || ':' || day_number || ':' || is_rest_day, ', ' order by position)
   from public.program_days where program_week_id = (select id from nw)),
  'Day 1:1:true, Day 2:2:true, Day 3:3:true, Day 4:4:true, Day 5:5:true, Day 6:6:true, Day 7:7:true',
  'add_program_week adds Day 1–7 as rest days, in order');
select is(
  (select min(position) from public.program_days where program_week_id = (select id from nw)),
  (select max(position) + 1 from public.program_days
   where program_id = (select p from t) and program_week_id <> (select id from nw)),
  'the new week''s days come after every other day');

-- The trigger: an 8th day is refused however it arrives.
select throws_like(
  $$ select public.add_program_day((select id from nw), 'Day 8', false) $$,
  'week_full:%', 'add_program_day refuses a full week');
select throws_like(
  $$ insert into public.program_days (program_id, program_week_id, user_id, day_number, title, position)
     select p, (select id from nw), a, 8, 'Day 8', 999 from t $$,
  'week_full:%', 'a direct insert into a full week is refused');
select throws_like(
  $$ select public.copy_program_day(
       (select id from public.program_days where program_week_id = (select w1 from t) order by position limit 1),
       array[(select id from nw)]) $$,
  'week_full:%', 'copy_program_day refuses a full target week');
select throws_like(
  $$ update public.program_days set program_week_id = (select id from nw)
     where id = (select id from public.program_days where program_week_id = (select w1 from t) order by position limit 1) $$,
  'week_full:%', 'moving a day into a full week is refused');
select lives_ok(
  $$ select public.duplicate_program_week((select id from nw)) $$,
  'duplicating a full week is fine: the copy is a new week');

-- add_program_day: after the week's last day, before the next week's days.
create temp table nd on commit drop as
select public.add_program_day((select w1 from t), 'Day 4', false) as id;
select is(
  (select row(day_number, title, is_rest_day)::text from public.program_days where id = (select id from nd)),
  '(4,"Day 4",f)', 'add_program_day numbers the day after the week''s others');
select ok(
  (select position from public.program_days where id = (select id from nd))
    < (select min(d.position) from public.program_days d where d.program_week_id = (select id from nw)),
  'the added day sits before the next week''s days');
select is(
  (select count(distinct position)::int = count(*)::int from public.program_days where program_id = (select p from t)),
  true, 'day positions stay unique');
select lives_ok(
  $$ select public.add_program_day((select w2 from t), 'Day 1', true) $$,
  'add_program_day fills an empty week');
select throws_like(
  $$ select public.add_program_day((select w1 from t), '  ', false) $$,
  'invalid_argument:%', 'add_program_day needs a title');

-- start_program: a day lands on start + 7 × week index + its place in the
-- week. Week 1 has 4 days (Mon–Thu), Week 2 one (next Mon), Week 3 seven.
create temp table run on commit drop as
select public.start_program((select p from t), '2026-11-16'::date) as id;
select is(
  (select string_agg(to_char(w.date, 'MM-DD'), ' ' order by w.date)
   from public.workouts w
   join public.program_days d on d.id = w.program_day_id
   where w.program_instance_id = (select id from run) and d.program_week_id = (select w1 from t)),
  '11-16 11-17 11-18 11-19', 'Week 1''s four days are its first four dates');
select is(
  (select w.date from public.workouts w
   join public.program_days d on d.id = w.program_day_id
   where w.program_instance_id = (select id from run) and d.program_week_id = (select w2 from t)),
  '2026-11-23'::date, 'Week 2 starts 7 days after Week 1, whatever Week 1 held');
select is(
  (select min(w.date) || '..' || max(w.date) from public.workouts w
   join public.program_days d on d.id = w.program_day_id
   where w.program_instance_id = (select id from run) and d.program_week_id = (select id from nw)),
  '2026-11-30..2026-12-06', 'Week 3 fills its calendar week');

select * from finish();
rollback;
