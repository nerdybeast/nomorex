-- Saving a reviewed AI import (#83). Runs as the seeded a@a.com (owner) and
-- b@b.com (another user). Exactly-once under real concurrency is in
-- ai_imports_concurrency.test.sql.
--
--   supabase test db        # local stack only; never --linked
begin;
create extension if not exists pgtap with schema extensions;
select plan(51);

create temp table t on commit drop as
select (select id from auth.users where email = 'a@a.com') as owner,
       (select id from auth.users where email = 'b@b.com') as other,
       (select id from public.exercises where name = 'Back Squat' and is_predefined limit 1) as squat,
       (select id from public.exercises where name = 'Bench Press' and is_predefined limit 1) as bench;
grant select on t to authenticated;

-- Written as superuser, because users can't insert job rows.
create function pg_temp.new_job(
  p_id uuid, p_type text, p_status text default 'ready', p_requested text default null
) returns void language sql as $$
  insert into public.ai_import_jobs (id, user_id, import_id, status, detected_type, requested_type)
  select p_id, owner, gen_random_uuid(), p_status, p_type, p_requested from t;
  insert into public.ai_import_results (job_id, user_id, payload)
  select p_id, owner, '{}'::jsonb from t where p_status = 'ready';
$$;

select pg_temp.new_job('10000000-0000-4000-8000-000000000001', 'workout');
select pg_temp.new_job('10000000-0000-4000-8000-000000000002', 'program');
select pg_temp.new_job('10000000-0000-4000-8000-000000000003', 'workout');
select pg_temp.new_job('10000000-0000-4000-8000-000000000004', 'workout', 'processing');
select pg_temp.new_job('10000000-0000-4000-8000-000000000005', 'program', 'ready', 'workout');
select pg_temp.new_job('10000000-0000-4000-8000-000000000006', 'workout');
select pg_temp.new_job('10000000-0000-4000-8000-000000000007', 'workout');

-- A custom exercise belonging to another user, which must never be linked.
insert into public.exercises (id, name, is_predefined, user_id)
select '20000000-0000-4000-8000-000000000001'::uuid, 'Pgtap Foreign Lift', false, other from t;
-- One of the owner's, for matching by name.
insert into public.exercises (id, name, is_predefined, user_id)
select '20000000-0000-4000-8000-000000000002'::uuid, 'Pgtap Sled Pull', false, owner from t;

select set_config('request.jwt.claims',
  json_build_object('sub', (select owner from t), 'role', 'authenticated')::text, true);
set local role authenticated;

-- ---------------------------------------------------------------------------
-- Workout
-- ---------------------------------------------------------------------------

create temp table workout_result on commit drop as
select public.ai_import_accept(
  '10000000-0000-4000-8000-000000000001'::uuid,
  jsonb_build_object(
    'title', 'Heavy day',
    'weeks', jsonb_build_array(jsonb_build_object('days', jsonb_build_array(jsonb_build_object(
      'isRestDay', false,
      'notes', 'Warm up well',
      'exercises', jsonb_build_array(
        jsonb_build_object(
          'name', 'Squat',
          'match', jsonb_build_object('exerciseId', (select squat from t), 'name', 'Back Squat', 'confidence', 'high'),
          'notes', 'Pause at the bottom',
          'sets', jsonb_build_array(
            jsonb_build_object('sets', 3, 'reps', 5, 'repsMax', 8, 'percent', 67, 'percentMax', 72.5,
                               'rpeMin', 6, 'rpeMax', 7,
                               'basisExercise', jsonb_build_object('name', 'Bench Press', 'match',
                                 jsonb_build_object('exerciseId', (select bench from t), 'name', 'Bench Press', 'confidence', 'exact'))),
            jsonb_build_object('reps', 1, 'weightKg', 140, 'note', 'Top single')
          )
        ),
        jsonb_build_object('name', 'pgtap made up lift', 'match', null, 'sets', jsonb_build_array(
          jsonb_build_object('sets', 2, 'weightKg', 20, 'unreadable', jsonb_build_array('reps'))
        )),
        jsonb_build_object('name', '  PGTAP Made Up Lift ', 'match', null, 'sets', jsonb_build_array(
          jsonb_build_object('reps', 10, 'percent', 50,
            'basisExercise', jsonb_build_object('name', 'pgtap made up lift', 'match', null))
        )),
        jsonb_build_object('name', 'pgtap sled pull', 'match', null, 'sets', '[]'::jsonb),
        jsonb_build_object('name', 'Pgtap Foreign Lift', 'match',
          jsonb_build_object('exerciseId', '20000000-0000-4000-8000-000000000001', 'name', 'Pgtap Foreign Lift', 'confidence', 'high'),
          'sets', '[]'::jsonb)
      )
    )))),
    'unstructured', jsonb_build_array(
      jsonb_build_object('location', 'Workout, Day 1, Squat', 'originalText', '3 x 10 light'),
      jsonb_build_object('location', 'Page 2', 'originalText', 'EMOM 10 min'),
      jsonb_build_object('originalText', 'Finisher: sled')
    )
  ),
  '2026-11-09'::date
) as r;

create temp table w on commit drop as
select ((r ->> 'workout_id')::uuid) as id from workout_result;
grant select on w to authenticated;

select is((select r ->> 'program_id' from workout_result), null, 'a workout import returns no program id');
select results_eq(
  $$ select title, date, user_id = auth.uid(), is_copy, is_imported, is_public,
            copied_from_user_id, copied_from_display_name, status
     from public.workouts where id = (select id from w) $$,
  $$ values ('Heavy day'::text, '2026-11-09'::date, true, true, true, false,
             null::uuid, null::text, 'not_started'::text) $$,
  'the workout is private, marked imported, credits nobody and is dated by the client');
select is((select notes from public.workouts where id = (select id from w)),
  E'Warm up well\nPage 2: EMOM 10 min\nFinisher: sled',
  'content with no exercise to sit on goes on the workout, with its location');

select results_eq(
  $$ select we.position, we.exercise_id = (select squat from t), we.notes
     from public.workout_exercises we where we.workout_id = (select id from w) and we.position = 0 $$,
  $$ values (0, true, E'Pause at the bottom\n3 x 10 light'::text) $$,
  'a confirmed match is used, and flagged content goes on the exercise it names');

select results_eq(
  $$ select ws.position, ws.target_reps, ws.target_reps_max, ws.weight_mode, ws.percentage,
            ws.percentage_max, ws.absolute_weight_kg, ws.rpe_min, ws.rpe_max,
            ws.basis_exercise_id = (select bench from t), ws.note
     from public.workout_sets ws
     join public.workout_exercises we on we.id = ws.workout_exercise_id
     where we.workout_id = (select id from w) and we.position = 0
     order by ws.position $$,
  $$ values (0, 5, 8, 'percentage'::text, 67::numeric, 72.5::numeric, null::numeric, 6.0::numeric, 7.0::numeric, true, null::text),
            (1, 5, 8, 'percentage', 67, 72.5, null, 6.0, 7.0, true, null),
            (2, 5, 8, 'percentage', 67, 72.5, null, 6.0, 7.0, true, null),
            (3, 1, null, 'absolute', null, null, 140, null, null, null, 'Top single') $$,
  'one row per set, with ranges, RPE, the basis lift and kg loads preserved');

select results_eq(
  $$ select ws.target_reps, ws.note
     from public.workout_sets ws
     join public.workout_exercises we on we.id = ws.workout_exercise_id
     where we.workout_id = (select id from w) and we.position = 1
     order by ws.position $$,
  $$ values (null::integer, 'Could not read: reps'::text), (null, 'Could not read: reps') $$,
  'an unread value stays empty and is flagged in the set note');

select is(
  (select count(*)::int from public.exercises
   where user_id = auth.uid() and lower(name) = 'pgtap made up lift'),
  1, 'repeated names, in any case and as a basis lift, create one custom exercise');
select is(
  (select name from public.exercises
   where user_id = auth.uid() and lower(name) = 'pgtap made up lift'),
  'pgtap made up lift', 'a new exercise keeps its name, trimmed');
select is(
  (select count(distinct we.exercise_id)::int
   from public.workout_exercises we
   join public.exercises e on e.id = we.exercise_id
   where we.workout_id = (select id from w) and lower(e.name) = 'pgtap made up lift'),
  1, 'both occurrences use that exercise');
select is(
  (select we.exercise_id from public.workout_exercises we
   where we.workout_id = (select id from w) and we.position = 3),
  '20000000-0000-4000-8000-000000000002'::uuid,
  'a name already in the catalog reuses that exercise, ignoring case');
select results_eq(
  $$ select e.user_id = auth.uid(), e.id <> '20000000-0000-4000-8000-000000000001'::uuid
     from public.workout_exercises we
     join public.exercises e on e.id = we.exercise_id
     where we.workout_id = (select id from w) and we.position = 4 $$,
  $$ values (true, true) $$,
  'an id for another user''s exercise is ignored, and the name resolves in the caller''s catalog');

select is(
  (select count(*)::int from public.workout_exercises
   where workout_id = (select id from w) and user_id is distinct from auth.uid()),
  0, 'every workout exercise carries the owner');
select is(
  (select count(*)::int from public.workout_sets ws
   join public.workout_exercises we on we.id = ws.workout_exercise_id
   where we.workout_id = (select id from w) and ws.user_id is distinct from auth.uid()),
  0, 'every workout set carries the owner');

select results_eq(
  $$ select status, accepted_workout_id = (select id from w), accepted_program_id
     from public.ai_import_jobs where id = '10000000-0000-4000-8000-000000000001'::uuid $$,
  $$ values ('accepted'::text, true, null::uuid) $$,
  'the job records the created workout');
select is(
  (select count(*)::int from public.ai_import_results
   where job_id = '10000000-0000-4000-8000-000000000001'::uuid),
  0, 'the result is removed once accepted');

-- ---------------------------------------------------------------------------
-- Accepting twice
-- ---------------------------------------------------------------------------

select is(
  public.ai_import_accept(
    '10000000-0000-4000-8000-000000000001'::uuid,
    '{"title": "Different"}'::jsonb, '2026-11-10'::date) ->> 'workout_id',
  (select id::text from w), 'a second accept returns the existing workout');
select is(
  (select count(*)::int from public.workouts where user_id = auth.uid() and title = 'Different'),
  0, 'a second accept creates nothing');

-- ---------------------------------------------------------------------------
-- Program
-- ---------------------------------------------------------------------------

create temp table program_result on commit drop as
select public.ai_import_accept(
  '10000000-0000-4000-8000-000000000002'::uuid,
  $json${
    "title": "Peaking block",
    "weeks": [
      {"label": "Week 1", "days": [
        {"weekday": "monday", "isRestDay": false, "notes": "Stay tight", "exercises": [
          {"name": "pgtap made up lift", "match": null, "sets": [{"sets": 2, "reps": 5, "weightKg": 100}]}
        ]},
        {"weekday": "tuesday", "isRestDay": true, "exercises": []},
        {"title": "Upper", "weekday": "wednesday", "isRestDay": false, "exercises": []}
      ]},
      {"days": [
        {"isRestDay": false, "exercises": [
          {"name": "Bench Press", "match": null, "sets": [{"reps": 3, "percent": 80, "percentMax": 85}]}
        ]},
        {"isRestDay": true, "exercises": [
          {"name": "Bench Press", "match": null, "sets": []}
        ]}
      ]}
    ],
    "unstructured": [
      {"location": "Week 1, Monday, pgtap made up lift", "originalText": "2 x max reps"},
      {"location": "Week 1, Wednesday", "originalText": "EMOM 12 min"},
      {"location": "Week 1, Someday", "originalText": "Row 2k"},
      {"location": "Week 9", "originalText": "Deload if tired"},
      {"originalText": "Coach: Sam"}
    ]
  }$json$::jsonb,
  '2026-11-09'::date
) as r;

create temp table p on commit drop as
select ((r ->> 'program_id')::uuid) as id from program_result;
grant select on p to authenticated;

select is((select r ->> 'workout_id' from program_result), null, 'a program import returns no workout id');
select results_eq(
  $$ select name, description, user_id = auth.uid(), is_copy, is_imported, is_public, copied_from_user_id
     from public.programs where id = (select id from p) $$,
  $$ values ('Peaking block'::text, E'Week 9: Deload if tired\nCoach: Sam'::text, true, true, true, false, null::uuid) $$,
  'the program is private and marked imported, and unplaceable content goes in its description');
select results_eq(
  $$ select week_number, label, notes, position from public.program_weeks
     where program_id = (select id from p) order by position $$,
  $$ values (1, 'Week 1'::text, 'Week 1, Someday: Row 2k'::text, 0), (2, null, null, 1) $$,
  'weeks are numbered in order, and content naming only a week goes on that week');
select results_eq(
  $$ select position, day_number, title, is_rest_day, notes from public.program_days
     where program_id = (select id from p) order by position $$,
  $$ values (0, 1, 'Monday'::text, false, 'Stay tight'::text),
            (1, 2, 'Tuesday', true, null),
            (2, 3, 'Upper', false, 'Week 1, Wednesday: EMOM 12 min'),
            (3, 1, 'Day 1', false, null),
            (4, 2, 'Rest day', false, null) $$,
  'day position is global, day_number restarts each week, and a "rest day" with exercises isn''t one');
select is(
  (select pe.notes from public.program_exercises pe
   join public.program_days pd on pd.id = pe.program_day_id
   where pd.program_id = (select id from p) and pd.position = 0),
  '2 x max reps', 'flagged content goes on the exercise it names');
select results_eq(
  $$ select ps.position, ps.target_reps, ps.weight_mode, ps.absolute_weight_kg
     from public.program_sets ps
     join public.program_exercises pe on pe.id = ps.program_exercise_id
     join public.program_days pd on pd.id = pe.program_day_id
     where pd.program_id = (select id from p) and pd.position = 0
     order by ps.position $$,
  $$ values (0, 5, 'absolute'::text, 100::numeric), (1, 5, 'absolute', 100) $$,
  'program sets are expanded the same way');
select results_eq(
  $$ select ps.percentage, ps.percentage_max
     from public.program_sets ps
     join public.program_exercises pe on pe.id = ps.program_exercise_id
     join public.program_days pd on pd.id = pe.program_day_id
     where pd.program_id = (select id from p) and pd.position = 3 $$,
  $$ values (80::numeric, 85::numeric) $$,
  'percentage ranges are preserved on program sets');
select is(
  (select pe.exercise_id from public.program_exercises pe
   join public.program_days pd on pd.id = pe.program_day_id
   where pd.program_id = (select id from p) and pd.position = 3),
  (select bench from t), 'an unmatched name that is in the catalog uses the predefined exercise');
select is(
  (select count(*)::int from public.exercises
   where user_id = auth.uid() and lower(name) = 'pgtap made up lift'),
  1, 'a later import reuses the custom exercise an earlier one created');

select is(
  (select count(*)::int from (
     select user_id from public.program_weeks where program_id = (select id from p)
     union all select user_id from public.program_days where program_id = (select id from p)
     union all select pe.user_id from public.program_exercises pe
       join public.program_days pd on pd.id = pe.program_day_id where pd.program_id = (select id from p)
     union all select ps.user_id from public.program_sets ps
       join public.program_exercises pe on pe.id = ps.program_exercise_id
       join public.program_days pd on pd.id = pe.program_day_id where pd.program_id = (select id from p)
   ) c where c.user_id is distinct from auth.uid()),
  0, 'every program child row carries the owner');
select is(
  (select count(*)::int from public.program_instances where program_id = (select id from p)),
  0, 'accepting a program does not start it');
select results_eq(
  $$ select accepted_program_id = (select id from p), accepted_workout_id
     from public.ai_import_jobs where id = '10000000-0000-4000-8000-000000000002'::uuid $$,
  $$ values (true, null::uuid) $$,
  'the job records the created program');

-- ---------------------------------------------------------------------------
-- The requested type wins
-- ---------------------------------------------------------------------------

select isnt(
  public.ai_import_accept(
    '10000000-0000-4000-8000-000000000005'::uuid,
    '{"weeks": [{"days": [{"isRestDay": false, "exercises": []}]}]}'::jsonb,
    '2026-11-09'::date) ->> 'workout_id',
  null, 're-running a program as a workout saves a workout');
select is(
  (select title from public.workouts w2
   join public.ai_import_jobs j on j.accepted_workout_id = w2.id
   where j.id = '10000000-0000-4000-8000-000000000005'::uuid),
  'Imported workout', 'a missing title gets a default');

-- ---------------------------------------------------------------------------
-- Refusals, and rolling back
-- ---------------------------------------------------------------------------

select throws_ok(
  $$ select public.ai_import_accept('10000000-0000-4000-8000-000000000004'::uuid, '{}'::jsonb, current_date) $$,
  'P0001', null, 'a job still processing cannot be accepted');
select throws_ok(
  $$ select public.ai_import_accept('10000000-0000-4000-8000-000000000003'::uuid, null, current_date) $$,
  'P0001', 'invalid_input: the reviewed import is required', 'a missing payload is refused');
select throws_ok(
  $$ select public.ai_import_accept('10000000-0000-4000-8000-000000000003'::uuid,
       '{"weeks": [{"days": [{"exercises": []}, {"exercises": []}]}]}'::jsonb, current_date) $$,
  'P0001', 'invalid_input: a workout has exactly one day', 'a workout with two days is refused, not cut short');

-- The new exercise is created before the bad set, so this proves the rollback.
select throws_ok(
  $$ select public.ai_import_accept('10000000-0000-4000-8000-000000000003'::uuid,
       '{"title": "Rolled back", "weeks": [{"days": [{"exercises": [
          {"name": "Pgtap Rolled Back Lift", "match": null, "sets": [{"reps": 5, "weight": 225, "unit": "lb"}]}
       ]}]}]}'::jsonb, current_date) $$,
  '23514', null, 'a load that was not converted to kg is refused');
select is((select count(*)::int from public.workouts where title = 'Rolled back'), 0,
  'a failed save leaves no workout');
select is((select count(*)::int from public.exercises where name = 'Pgtap Rolled Back Lift'), 0,
  'a failed save leaves no custom exercise');
select results_eq(
  $$ select status, accepted_workout_id from public.ai_import_jobs
     where id = '10000000-0000-4000-8000-000000000003'::uuid $$,
  $$ values ('ready'::text, null::uuid) $$,
  'a failed save leaves the job ready to retry');
select is((select count(*)::int from public.ai_import_results
   where job_id = '10000000-0000-4000-8000-000000000003'::uuid), 1,
  'a failed save keeps the result');

select throws_ok(
  $$ select public.ai_import_accept('10000000-0000-4000-8000-000000000003'::uuid,
       '{"weeks": [{"days": [{"exercises": [
          {"name": "Bench Press", "match": null, "sets": [{"reps": 8, "repsMax": 5, "weightKg": 60}]}
       ]}]}]}'::jsonb, current_date) $$,
  '23514', null, 'a rep range top below its bottom is refused');
select throws_ok(
  $$ select public.ai_import_accept('10000000-0000-4000-8000-000000000003'::uuid,
       '{"weeks": [{"days": [{"exercises": [
          {"name": "Bench Press", "match": null, "sets": [{"reps": 5, "percent": 80, "percentMax": 70}]}
       ]}]}]}'::jsonb, current_date) $$,
  '23514', null, 'a percentage range top below its bottom is refused');
select throws_ok(
  $$ select public.ai_import_accept('10000000-0000-4000-8000-000000000003'::uuid,
       '{"weeks": [{"days": [{"exercises": [
          {"name": "Bench Press", "match": null, "sets": [{"sets": 51, "reps": 5, "weightKg": 60}]}
       ]}]}]}'::jsonb, current_date) $$,
  'P0001', 'invalid_input: a set count must be between 1 and 50', 'an absurd set count is refused');
select throws_ok(
  $$ select public.ai_import_accept('10000000-0000-4000-8000-000000000003'::uuid,
       '{"weeks": [{"days": [{"exercises": [{"name": "   ", "match": null, "sets": []}]}]}]}'::jsonb, current_date) $$,
  'P0001', 'invalid_input: an exercise needs a name', 'a blank exercise name is refused');

-- ---------------------------------------------------------------------------
-- Staying private
-- ---------------------------------------------------------------------------

select throws_ok(
  $$ update public.workouts set is_public = true where id = (select id from w) $$,
  '23514', null, 'an imported workout cannot be made public');
select throws_ok(
  $$ update public.programs set is_public = true where id = (select id from p) $$,
  '23514', null, 'an imported program cannot be made public');
select throws_ok(
  $$ update public.workouts set is_copy = false where id = (select id from w) $$,
  'P0001', 'copy_is_permanent: a copy cannot be un-marked', 'an imported workout cannot be un-marked');
select throws_ok(
  $$ update public.programs set is_copy = false where id = (select id from p) $$,
  'P0001', 'copy_is_permanent: a copy cannot be un-marked', 'an imported program cannot be un-marked');

-- ---------------------------------------------------------------------------
-- Running an imported program
-- ---------------------------------------------------------------------------

create temp table run on commit drop as
select public.start_program((select id from p), '2026-11-16'::date) as id;

select is(
  (select count(*)::int from public.workouts
   where program_instance_id = (select id from run) and is_imported and is_copy),
  5, 'start_program carries is_imported onto every materialized workout');
select is(
  (select notes from public.workouts
   where program_instance_id = (select id from run) and date = '2026-11-16'::date),
  'Stay tight', 'start_program carries the day''s notes onto its workout');

-- ---------------------------------------------------------------------------
-- Other users
-- ---------------------------------------------------------------------------

reset role;
select set_config('request.jwt.claims',
  json_build_object('sub', (select other from t), 'role', 'authenticated')::text, true);
set local role authenticated;

select throws_ok(
  $$ select public.ai_import_accept('10000000-0000-4000-8000-000000000006'::uuid, '{}'::jsonb, current_date) $$,
  'P0001', null, 'another user''s import is refused');

reset role;
select is((select status from public.ai_import_jobs where id = '10000000-0000-4000-8000-000000000006'::uuid),
  'ready', 'a refused accept leaves the job alone');

select * from finish();
rollback;
