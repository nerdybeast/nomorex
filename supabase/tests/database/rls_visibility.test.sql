-- What another signed-in user can see of someone's shared content (#34).
--
-- a@a.com (who owns no public content in seed.sql) is the author; b@b.com
-- is the viewer. Public workouts and programs are readable with their whole
-- tree; private ones (rls_ownership.test.sql) are not. Exercises and the
-- author's profile become visible only through public content. The anon role
-- sees nothing at all.
--
--   supabase test db        # local stack only; never --linked
begin;
create extension if not exists pgtap with schema extensions;
select plan(30);

-- ---------------------------------------------------------------------------
-- Fixtures, written as superuser with fixed ids.
-- ---------------------------------------------------------------------------

create temp table u on commit drop as
select (select id from auth.users where email = 'a@a.com') as a,
       (select id from auth.users where email = 'b@b.com') as b,
       (select id from public.exercises where is_predefined limit 1) as predefined,
       '00000000-0000-4000-8000-00000000c001'::uuid as lift_in_workout,   -- a's custom, used in a's public workout
       '00000000-0000-4000-8000-00000000c002'::uuid as lift_as_basis,     -- a's custom, only a basis in a's public program
       '00000000-0000-4000-8000-00000000c003'::uuid as lift_unshared,     -- a's custom, used nowhere public
       '00000000-0000-4000-8000-00000000c010'::uuid as pub_workout,
       '00000000-0000-4000-8000-00000000c011'::uuid as pub_we,
       '00000000-0000-4000-8000-00000000c012'::uuid as pub_ws,
       '00000000-0000-4000-8000-00000000c020'::uuid as pub_program,
       '00000000-0000-4000-8000-00000000c021'::uuid as pub_week,
       '00000000-0000-4000-8000-00000000c022'::uuid as pub_day,
       '00000000-0000-4000-8000-00000000c023'::uuid as pub_pe,
       '00000000-0000-4000-8000-00000000c024'::uuid as pub_ps,
       '00000000-0000-4000-8000-00000000c025'::uuid as pub_instance;
grant select on u to authenticated, anon;

select is((select count(*)::int from public.workouts w join u on w.user_id = u.a where w.is_public)
        + (select count(*)::int from public.programs p join u on p.user_id = u.a where p.is_public),
  0, 'a starts with no public content, so a''s profile is hidden until the fixtures share some');

insert into public.exercises (id, name, is_predefined, user_id)
select lift_in_workout, 'pgTAP vis lift in workout', false, a from u
union all select lift_as_basis, 'pgTAP vis basis lift', false, a from u
union all select lift_unshared, 'pgTAP vis unshared lift', false, a from u;

insert into public.workouts (id, user_id, title, date, is_public)
select pub_workout, a, 'pgTAP vis public workout', current_date, true from u;
insert into public.workout_exercises (id, workout_id, user_id, exercise_id, position)
select pub_we, pub_workout, a, lift_in_workout, 0 from u;
insert into public.workout_sets (id, workout_exercise_id, user_id, position, target_reps, weight_mode, absolute_weight_kg)
select pub_ws, pub_we, a, 0, 5, 'absolute', 80 from u;

insert into public.programs (id, user_id, name, is_public)
select pub_program, a, 'pgTAP vis public program', true from u;
insert into public.program_weeks (id, program_id, user_id, week_number, position)
select pub_week, pub_program, a, 1, 0 from u;
insert into public.program_days (id, program_id, program_week_id, user_id, day_number, title, position)
select pub_day, pub_program, pub_week, a, 1, 'Day 1', 0 from u;
insert into public.program_exercises (id, program_day_id, user_id, exercise_id, position)
select pub_pe, pub_day, a, predefined, 0 from u;
-- "Predefined lift @ 70% of a's custom lift": the basis is visible only through this set.
insert into public.program_sets (id, program_exercise_id, user_id, position, target_reps, weight_mode, percentage, basis_exercise_id)
select pub_ps, pub_pe, a, 0, 5, 'percentage', 70, lift_as_basis from u;
insert into public.program_instances (id, program_id, user_id)
select pub_instance, pub_program, a from u;

-- ---------------------------------------------------------------------------
-- As b@b.com
-- ---------------------------------------------------------------------------

select set_config('request.jwt.claims', json_build_object('sub', (select b from u), 'role', 'authenticated')::text, true);
set local role authenticated;

-- A public workout is readable with its whole tree.
select is((select count(*)::int from public.workouts where id = (select pub_workout from u)), 1,
  'b can see a''s public workout');
select is((select count(*)::int from public.workout_exercises where id = (select pub_we from u)), 1,
  'b can see a''s public workout''s exercises');
select is((select count(*)::int from public.workout_sets where id = (select pub_ws from u)), 1,
  'b can see a''s public workout''s sets');

-- So is a public program.
select is((select count(*)::int from public.programs where id = (select pub_program from u)), 1,
  'b can see a''s public program');
select is((select count(*)::int from public.program_weeks where id = (select pub_week from u)), 1,
  'b can see a''s public program''s weeks');
select is((select count(*)::int from public.program_days where id = (select pub_day from u)), 1,
  'b can see a''s public program''s days');
select is((select count(*)::int from public.program_exercises where id = (select pub_pe from u)), 1,
  'b can see a''s public program''s exercises');
select is((select count(*)::int from public.program_sets where id = (select pub_ps from u)), 1,
  'b can see a''s public program''s sets');
-- ...but a's run of it is a's own history.
select is((select count(*)::int from public.program_instances where id = (select pub_instance from u)), 0,
  'b cannot see a''s run of a public program');

-- Exercises: predefined for everyone; a custom one only through public content.
select ok((select count(*) from public.exercises where is_predefined) > 0,
  'b can see predefined exercises');
select is((select count(*)::int from public.exercises where id = (select lift_in_workout from u)), 1,
  'b can see a''s custom exercise used in a public workout');
select is((select count(*)::int from public.exercises where id = (select lift_as_basis from u)), 1,
  'b can see a''s custom exercise used as a public program set''s 1RM basis');
select is((select count(*)::int from public.exercises where id = (select lift_unshared from u)), 0,
  'b cannot see a''s custom exercise that isn''t in anything public');

-- Seeing it isn't owning it: b can't change a's public content.
select is(
  (select count(*)::int from public.workouts where id = (select pub_workout from u) and title = 'pgTAP vis public workout'), 1,
  'precondition: the public workout has its original title');
update public.workouts set title = 'defaced' where id = (select pub_workout from u);
update public.workout_sets set absolute_weight_kg = 999 where id = (select pub_ws from u);
update public.programs set is_public = false where id = (select pub_program from u);
update public.exercises set name = 'defaced' where id = (select lift_in_workout from u);
delete from public.program_sets where id = (select pub_ps from u);
delete from public.workouts where id = (select pub_workout from u);

-- The author's profile is visible because a now shares something.
select is((select count(*)::int from public.profiles where id = (select a from u)), 1,
  'b can see a''s profile while a has public content');

-- Column exposure: RLS is row-level and the table grant is table-wide, so a
-- visible profile shows every column. Listed here so that adding a column to
-- profiles is a decision about whether other users should see it.
select is(
  (select array_agg(column_name::text order by column_name::text)
   from information_schema.columns c
   where c.table_schema = 'public' and c.table_name = 'profiles'
     and has_column_privilege('authenticated', 'public.profiles', c.column_name, 'select')),
  array['created_at', 'display_name', 'id', 'one_rep_max_formula', 'unit_preference', 'updated_at'],
  'other users who can see a profile can read exactly these columns');

-- ---------------------------------------------------------------------------
-- Back as superuser: b's writes above changed nothing.
-- ---------------------------------------------------------------------------

reset role;

select is((select title from public.workouts where id = (select pub_workout from u)), 'pgTAP vis public workout',
  'b''s update did not rename a''s public workout, and b''s delete did not remove it');
select is((select absolute_weight_kg from public.workout_sets where id = (select pub_ws from u)), 80::numeric,
  'b''s update did not change a''s public workout''s set');
select is((select is_public from public.programs where id = (select pub_program from u)), true,
  'b''s update did not make a''s public program private');
select is((select count(*)::int from public.program_sets where id = (select pub_ps from u)), 1,
  'b''s delete did not remove a''s public program''s set');
select is((select name from public.exercises where id = (select lift_in_workout from u)), 'pgTAP vis lift in workout',
  'b''s update did not rename a''s custom exercise');

-- Making the content private again hides it, children and profile included.
update public.workouts set is_public = false where id = (select pub_workout from u);
update public.programs set is_public = false where id = (select pub_program from u);

select set_config('request.jwt.claims', json_build_object('sub', (select b from u), 'role', 'authenticated')::text, true);
set local role authenticated;

select is(
  (select count(*)::int from public.workouts where id = (select pub_workout from u))
  + (select count(*)::int from public.workout_sets where id = (select pub_ws from u))
  + (select count(*)::int from public.programs where id = (select pub_program from u))
  + (select count(*)::int from public.program_sets where id = (select pub_ps from u)),
  0, 'once a makes them private, b sees neither the workout, the program, nor their children');
select is((select count(*)::int from public.exercises where id in ((select lift_in_workout from u), (select lift_as_basis from u))), 0,
  'once nothing public uses them, b no longer sees a''s custom exercises');
select is((select count(*)::int from public.profiles where id = (select a from u)), 0,
  'once a shares nothing, b no longer sees a''s profile');

-- An archived public workout no longer exposes its author's profile.
reset role;
update public.workouts set is_public = true, is_archived = true, archived_at = now() where id = (select pub_workout from u);
select set_config('request.jwt.claims', json_build_object('sub', (select b from u), 'role', 'authenticated')::text, true);
set local role authenticated;
select is((select count(*)::int from public.profiles where id = (select a from u)), 0,
  'a public but archived workout does not expose a''s profile');

-- ---------------------------------------------------------------------------
-- anon (the publishable key with no session) sees nothing, public or not.
-- ---------------------------------------------------------------------------

reset role;
update public.workouts set is_archived = false, archived_at = null where id = (select pub_workout from u);
update public.programs set is_public = true where id = (select pub_program from u);
select set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
set local role anon;

select is(
  (select count(*)::int from public.workouts where id = (select pub_workout from u))
  + (select count(*)::int from public.workout_sets where id = (select pub_ws from u))
  + (select count(*)::int from public.programs where id = (select pub_program from u))
  + (select count(*)::int from public.program_sets where id = (select pub_ps from u)),
  0, 'anon cannot see public workouts, programs or their children');
select is((select count(*)::int from public.exercises), 0,
  'anon cannot see any exercise, predefined included');
select is((select count(*)::int from public.profiles), 0,
  'anon cannot see any profile');
select throws_ok(
  $$ insert into public.workouts (user_id, title, date) select a, 'anon forged', current_date from u $$,
  '42501', null, 'anon cannot insert a workout');

select * from finish();
rollback;
