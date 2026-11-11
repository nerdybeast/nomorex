-- Row Level Security keeps each user's private rows to themselves (#34).
-- The app talks to PostgREST directly, so these policies are the only thing
-- stopping a signed-in user from reading or changing someone else's data;
-- `supabase db lint` only checks that RLS is on, not that it's right.
--
-- a@a.com owns a private row in every user-owned table; b@b.com tries to
-- read, insert, update, delete and reassign them. The ai_import_* tables and
-- the ai-imports bucket are covered in ai_imports.test.sql; visibility of
-- public content in rls_visibility.test.sql; RPCs in rls_rpcs.test.sql.
--
--   supabase test db        # local stack only; never --linked
begin;
create extension if not exists pgtap with schema extensions;
select plan(64);

-- ---------------------------------------------------------------------------
-- Fixtures, written as superuser: a complete private tree for each user.
-- ---------------------------------------------------------------------------

create temp table u on commit drop as
select (select id from auth.users where email = 'a@a.com') as a,
       (select id from auth.users where email = 'b@b.com') as b,
       (select id from public.exercises where is_predefined limit 1) as predefined;
grant select on u to authenticated;

select isnt((select a from u), null, 'seeded user a@a.com exists');
select isnt((select b from u), null, 'seeded user b@b.com exists');

-- fx(owner, kind) -> id of that user's fixture row of that kind.
create temp table fx (owner text, kind text, id uuid default gen_random_uuid(), primary key (owner, kind)) on commit drop;
grant select on fx to authenticated;

create function pg_temp.fx(p_owner text, p_kind text) returns uuid
language sql stable as $$ select id from fx where owner = p_owner and kind = p_kind $$;

create function pg_temp.build_tree(p_owner text, p_user uuid) returns void
language plpgsql as $$
begin
  insert into fx (owner, kind)
  select p_owner, k from unnest(array['exercise', 'pr', 'workout', 'workout_exercise', 'workout_set',
    'program', 'week', 'day', 'program_exercise', 'program_set', 'instance']) k;

  insert into public.exercises (id, name, is_predefined, user_id)
  values (pg_temp.fx(p_owner, 'exercise'), 'pgTAP RLS custom lift ' || p_owner, false, p_user);
  insert into public.personal_bests (id, user_id, exercise_id, weight_kg, reps, date)
  values (pg_temp.fx(p_owner, 'pr'), p_user, pg_temp.fx(p_owner, 'exercise'), 100, 1, current_date);

  insert into public.workouts (id, user_id, title, date)
  values (pg_temp.fx(p_owner, 'workout'), p_user, 'pgTAP RLS private workout ' || p_owner, current_date);
  insert into public.workout_exercises (id, workout_id, user_id, exercise_id, position)
  values (pg_temp.fx(p_owner, 'workout_exercise'), pg_temp.fx(p_owner, 'workout'), p_user,
          pg_temp.fx(p_owner, 'exercise'), 0);
  insert into public.workout_sets (id, workout_exercise_id, user_id, position, target_reps, weight_mode, absolute_weight_kg)
  values (pg_temp.fx(p_owner, 'workout_set'), pg_temp.fx(p_owner, 'workout_exercise'), p_user, 0, 5, 'absolute', 80);

  insert into public.programs (id, user_id, name)
  values (pg_temp.fx(p_owner, 'program'), p_user, 'pgTAP RLS private program ' || p_owner);
  insert into public.program_weeks (id, program_id, user_id, week_number, position)
  values (pg_temp.fx(p_owner, 'week'), pg_temp.fx(p_owner, 'program'), p_user, 1, 0);
  insert into public.program_days (id, program_id, program_week_id, user_id, day_number, title, position)
  values (pg_temp.fx(p_owner, 'day'), pg_temp.fx(p_owner, 'program'), pg_temp.fx(p_owner, 'week'), p_user, 1, 'Day 1', 0);
  insert into public.program_exercises (id, program_day_id, user_id, exercise_id, position)
  values (pg_temp.fx(p_owner, 'program_exercise'), pg_temp.fx(p_owner, 'day'), p_user, pg_temp.fx(p_owner, 'exercise'), 0);
  insert into public.program_sets (id, program_exercise_id, user_id, position, target_reps, weight_mode, percentage)
  values (pg_temp.fx(p_owner, 'program_set'), pg_temp.fx(p_owner, 'program_exercise'), p_user, 0, 5, 'percentage', 70);
  insert into public.program_instances (id, program_id, user_id)
  values (pg_temp.fx(p_owner, 'instance'), pg_temp.fx(p_owner, 'program'), p_user);
end;
$$;

select pg_temp.build_tree('a', a) from u;
select pg_temp.build_tree('b', b) from u;

-- Rows an UPDATE/DELETE statement touched. RLS filters USING silently, so
-- "changed nothing" is the observable outcome, not an error.
create function pg_temp.affected(p_sql text) returns int
language plpgsql as $$
declare n int;
begin
  execute p_sql;
  get diagnostics n = row_count;
  return n;
end;
$$;

-- table name -> its fixture kind, for the per-table loops below.
create temp table owned (tbl text, kind text, key_col text) on commit drop;
insert into owned values
  ('exercises', 'exercise', 'id'), ('personal_bests', 'pr', 'id'),
  ('workouts', 'workout', 'id'), ('workout_exercises', 'workout_exercise', 'id'),
  ('workout_sets', 'workout_set', 'id'), ('programs', 'program', 'id'),
  ('program_weeks', 'week', 'id'), ('program_days', 'day', 'id'),
  ('program_exercises', 'program_exercise', 'id'), ('program_sets', 'program_set', 'id'),
  ('program_instances', 'instance', 'id');
grant select on owned to authenticated;

-- ---------------------------------------------------------------------------
-- As b@b.com
-- ---------------------------------------------------------------------------

select set_config('request.jwt.claims', json_build_object('sub', (select b from u), 'role', 'authenticated')::text, true);
set local role authenticated;

-- SELECT: none of a's private rows are visible (11 tables + profiles below).
select is(
  (select count(*)::int from public.exercises where id = pg_temp.fx('a', 'exercise')), 0,
  'b cannot see a''s custom exercise');
select is(
  (select count(*)::int from public.personal_bests where id = pg_temp.fx('a', 'pr')), 0,
  'b cannot see a''s personal bests');
select is(
  (select count(*)::int from public.workouts where id = pg_temp.fx('a', 'workout')), 0,
  'b cannot see a''s private workout');
select is(
  (select count(*)::int from public.workout_exercises where id = pg_temp.fx('a', 'workout_exercise')), 0,
  'b cannot see a''s private workout''s exercises');
select is(
  (select count(*)::int from public.workout_sets where id = pg_temp.fx('a', 'workout_set')), 0,
  'b cannot see a''s private workout''s sets');
select is(
  (select count(*)::int from public.programs where id = pg_temp.fx('a', 'program')), 0,
  'b cannot see a''s private program');
select is(
  (select count(*)::int from public.program_weeks where id = pg_temp.fx('a', 'week')), 0,
  'b cannot see a''s private program''s weeks');
select is(
  (select count(*)::int from public.program_days where id = pg_temp.fx('a', 'day')), 0,
  'b cannot see a''s private program''s days');
select is(
  (select count(*)::int from public.program_exercises where id = pg_temp.fx('a', 'program_exercise')), 0,
  'b cannot see a''s private program''s exercises');
select is(
  (select count(*)::int from public.program_sets where id = pg_temp.fx('a', 'program_set')), 0,
  'b cannot see a''s private program''s sets');
select is(
  (select count(*)::int from public.program_instances where id = pg_temp.fx('a', 'instance')), 0,
  'b cannot see a''s program runs');
select is(
  (select count(*)::int from public.profiles where id = (select a from u)), 0,
  'b cannot see a''s profile while a shares nothing');

-- Sanity: b does see b's own rows, so the zeros above aren't a broken fixture.
select is(
  (select count(*)::int from owned o
   where exists (select 1 from fx where fx.owner = 'b' and fx.kind = o.kind)),
  11, 'b has a fixture row in each of the 11 tables');
select is(
  (select count(*)::int from public.workout_sets where id = pg_temp.fx('b', 'workout_set'))
  + (select count(*)::int from public.program_instances where id = pg_temp.fx('b', 'instance'))
  + (select count(*)::int from public.exercises where id = pg_temp.fx('b', 'exercise')),
  3, 'b can see b''s own rows');

-- INSERT as a: refused by every table's WITH CHECK.
select throws_ok(
  $$ insert into public.exercises (name, is_predefined, user_id) select 'forged', false, a from u $$,
  '42501', null, 'b cannot insert a custom exercise owned by a');
select throws_ok(
  $$ insert into public.personal_bests (user_id, exercise_id, weight_kg, reps, date)
     select a, predefined, 100, 1, current_date from u $$,
  '42501', null, 'b cannot insert a personal best for a');
select throws_ok(
  $$ insert into public.workouts (user_id, title, date) select a, 'forged', current_date from u $$,
  '42501', null, 'b cannot insert a workout owned by a');
select throws_ok(
  $$ insert into public.workout_exercises (workout_id, user_id, exercise_id, position)
     select pg_temp.fx('a', 'workout'), a, predefined, 9 from u $$,
  '42501', null, 'b cannot insert a workout exercise owned by a');
select throws_ok(
  $$ insert into public.workout_sets (workout_exercise_id, user_id, position, target_reps, weight_mode, absolute_weight_kg)
     select pg_temp.fx('a', 'workout_exercise'), a, 9, 5, 'absolute', 80 from u $$,
  '42501', null, 'b cannot insert a workout set owned by a');
select throws_ok(
  $$ insert into public.programs (user_id, name) select a, 'forged' from u $$,
  '42501', null, 'b cannot insert a program owned by a');
select throws_ok(
  $$ insert into public.program_weeks (program_id, user_id, week_number, position)
     select pg_temp.fx('a', 'program'), a, 9, 9 from u $$,
  '42501', null, 'b cannot insert a program week owned by a');
select throws_ok(
  $$ insert into public.program_days (program_id, program_week_id, user_id, day_number, title, position)
     select pg_temp.fx('a', 'program'), pg_temp.fx('a', 'week'), a, 9, 'forged', 9 from u $$,
  '42501', null, 'b cannot insert a program day owned by a');
select throws_ok(
  $$ insert into public.program_exercises (program_day_id, user_id, exercise_id, position)
     select pg_temp.fx('a', 'day'), a, predefined, 9 from u $$,
  '42501', null, 'b cannot insert a program exercise owned by a');
select throws_ok(
  $$ insert into public.program_sets (program_exercise_id, user_id, position, target_reps, weight_mode, percentage)
     select pg_temp.fx('a', 'program_exercise'), a, 9, 5, 'percentage', 70 from u $$,
  '42501', null, 'b cannot insert a program set owned by a');
select throws_ok(
  $$ insert into public.program_instances (program_id, user_id) select pg_temp.fx('a', 'program'), a from u $$,
  '42501', null, 'b cannot insert a program run owned by a');

-- UPDATE and DELETE of a's rows change nothing (one test per table each).
select is(
  (select sum(pg_temp.affected(format(
     'update public.%I set created_at = created_at where %I = %L', tbl, key_col, pg_temp.fx('a', kind))))::int
   from owned),
  0, 'b''s updates to a''s rows touch none of them, in any of the 11 tables');
select is(
  pg_temp.affected(format('update public.profiles set display_name = %L where id = %L', 'hijacked', (select a from u))),
  0, 'b cannot rename a''s profile');
select is(
  (select sum(pg_temp.affected(format(
     'delete from public.%I where %I = %L', tbl, key_col, pg_temp.fx('a', kind))))::int
   from owned),
  0, 'b''s deletes of a''s rows touch none of them, in any of the 11 tables');

-- Reassigning b's own row to a is refused by WITH CHECK on every table.
select throws_ok(
  $$ update public.exercises set user_id = (select a from u) where id = pg_temp.fx('b', 'exercise') $$,
  '42501', null, 'b cannot hand b''s custom exercise to a');
select throws_ok(
  $$ update public.personal_bests set user_id = (select a from u) where id = pg_temp.fx('b', 'pr') $$,
  '42501', null, 'b cannot hand b''s personal best to a');
select throws_ok(
  $$ update public.workouts set user_id = (select a from u) where id = pg_temp.fx('b', 'workout') $$,
  '42501', null, 'b cannot hand b''s workout to a');
select throws_ok(
  $$ update public.workout_exercises set user_id = (select a from u) where id = pg_temp.fx('b', 'workout_exercise') $$,
  '42501', null, 'b cannot hand b''s workout exercise to a');
select throws_ok(
  $$ update public.workout_sets set user_id = (select a from u) where id = pg_temp.fx('b', 'workout_set') $$,
  '42501', null, 'b cannot hand b''s workout set to a');
select throws_ok(
  $$ update public.programs set user_id = (select a from u) where id = pg_temp.fx('b', 'program') $$,
  '42501', null, 'b cannot hand b''s program to a');
select throws_ok(
  $$ update public.program_weeks set user_id = (select a from u) where id = pg_temp.fx('b', 'week') $$,
  '42501', null, 'b cannot hand b''s program week to a');
select throws_ok(
  $$ update public.program_days set user_id = (select a from u) where id = pg_temp.fx('b', 'day') $$,
  '42501', null, 'b cannot hand b''s program day to a');
select throws_ok(
  $$ update public.program_exercises set user_id = (select a from u) where id = pg_temp.fx('b', 'program_exercise') $$,
  '42501', null, 'b cannot hand b''s program exercise to a');
select throws_ok(
  $$ update public.program_sets set user_id = (select a from u) where id = pg_temp.fx('b', 'program_set') $$,
  '42501', null, 'b cannot hand b''s program set to a');
select throws_ok(
  $$ update public.program_instances set user_id = (select a from u) where id = pg_temp.fx('b', 'instance') $$,
  '42501', null, 'b cannot hand b''s program run to a');
select throws_ok(
  $$ update public.profiles set id = (select a from u) where id = (select b from u) $$,
  '42501', null, 'b cannot re-key b''s profile as a');

-- Predefined exercises belong to nobody, so nobody can edit or delete them.
select is(
  pg_temp.affected(format('update public.exercises set name = name where id = %L', (select predefined from u))),
  0, 'b cannot edit a predefined exercise');
select is(
  pg_temp.affected(format('delete from public.exercises where id = %L', (select predefined from u))),
  0, 'b cannot delete a predefined exercise');
select throws_ok(
  $$ insert into public.exercises (name, is_predefined, user_id) values ('forged predefined', true, null) $$,
  '42501', null, 'b cannot add a predefined exercise');

-- Roles (20261111214805_add_admin_roles.sql): a@a.com is the seeded admin.
-- Role rows are written only by the admin_* functions (admin.test.sql).
select is((select count(*)::int from public.user_roles where user_id = (select a from u)), 0,
  'b cannot see a''s role');
select throws_ok(
  $$ insert into public.user_roles (user_id, role) select b, 'admin' from u $$,
  '42501', null, 'b cannot give themselves a role');
select throws_ok(
  $$ delete from public.user_roles where user_id = (select a from u) $$,
  '42501', null, 'b cannot remove a''s role');

-- ---------------------------------------------------------------------------
-- Attaching b's own rows to a's parents.
--
-- Child policies check only user_id, so b used to be able to stamp a row with
-- b's own id and hang it off a's workout or program (on a public workout
-- every viewer saw it, and a couldn't delete it). The check_parent_owner
-- triggers now refuse a row whose parent has a different owner
-- (20261111022449_child_rows_require_owned_parent.sql).
-- ---------------------------------------------------------------------------

select throws_ok(
  $$ insert into public.workout_exercises (workout_id, user_id, exercise_id, position)
     select pg_temp.fx('a', 'workout'), b, predefined, 9 from u $$,
  '42501', null, 'b cannot attach b''s exercise to a''s workout');
select throws_ok(
  $$ insert into public.workout_sets (workout_exercise_id, user_id, position, target_reps, weight_mode, absolute_weight_kg)
     select pg_temp.fx('a', 'workout_exercise'), b, 9, 5, 'absolute', 80 from u $$,
  '42501', null, 'b cannot attach b''s set to a''s workout exercise');
select throws_ok(
  $$ insert into public.program_weeks (program_id, user_id, week_number, position)
     select pg_temp.fx('a', 'program'), b, 9, 9 from u $$,
  '42501', null, 'b cannot attach b''s week to a''s program');
select throws_ok(
  $$ insert into public.program_days (program_id, program_week_id, user_id, day_number, title, position)
     select pg_temp.fx('a', 'program'), pg_temp.fx('a', 'week'), b, 9, 'injected', 9 from u $$,
  '42501', null, 'b cannot attach b''s day to a''s program');
select throws_ok(
  $$ insert into public.program_exercises (program_day_id, user_id, exercise_id, position)
     select pg_temp.fx('a', 'day'), b, predefined, 9 from u $$,
  '42501', null, 'b cannot attach b''s exercise to a''s program day');
select throws_ok(
  $$ insert into public.program_sets (program_exercise_id, user_id, position, target_reps, weight_mode, percentage)
     select pg_temp.fx('a', 'program_exercise'), b, 9, 5, 'percentage', 70 from u $$,
  '42501', null, 'b cannot attach b''s set to a''s program exercise');
select throws_ok(
  $$ update public.workout_exercises set workout_id = pg_temp.fx('a', 'workout')
     where id = pg_temp.fx('b', 'workout_exercise') $$,
  '42501', null, 'b cannot move b''s workout exercise into a''s workout');

select throws_ok(
  $$ update public.program_sets set program_exercise_id = pg_temp.fx('a', 'program_exercise')
     where id = pg_temp.fx('b', 'program_set') $$,
  '42501', null, 'b cannot move b''s program set into a''s program');
select throws_ok(
  $$ insert into public.program_days (program_id, program_week_id, user_id, day_number, title, position)
     select pg_temp.fx('b', 'program'), pg_temp.fx('a', 'week'), b, 9, 'mixed', 9 from u $$,
  '42501', null, 'b cannot hang a day of b''s program off a''s week');
select throws_ok(
  $$ insert into public.program_instances (program_id, user_id) select pg_temp.fx('a', 'program'), b from u $$,
  '42501', null, 'b cannot start a run of a''s program by inserting it directly');
select throws_ok(
  $$ insert into public.workouts (user_id, title, date, program_instance_id)
     select b, 'linked', current_date, pg_temp.fx('a', 'instance') from u $$,
  '42501', null, 'b cannot link a workout to a''s program run');
select throws_ok(
  $$ update public.workouts set program_day_id = pg_temp.fx('a', 'day') where id = pg_temp.fx('b', 'workout') $$,
  '42501', null, 'b cannot link b''s workout to a day of a''s program');

-- b's own trees still work end to end through the tightened policies.
select lives_ok(
  $$ insert into public.workout_sets (workout_exercise_id, user_id, position, target_reps, weight_mode, absolute_weight_kg)
     select pg_temp.fx('b', 'workout_exercise'), b, 9, 5, 'absolute', 80 from u $$,
  'b can still add a set to b''s own workout');
select lives_ok(
  $$ insert into public.program_days (program_id, program_week_id, user_id, day_number, title, position)
     select pg_temp.fx('b', 'program'), pg_temp.fx('b', 'week'), b, 2, 'Day 2', 9 from u $$,
  'b can still add a day to b''s own program');
select lives_ok(
  $$ insert into public.workouts (user_id, title, date, program_instance_id, program_day_id)
     select b, 'linked', current_date, pg_temp.fx('b', 'instance'), pg_temp.fx('b', 'day') from u $$,
  'b can still link a workout to b''s own program run and day');
select lives_ok(
  $$ select public.start_program(pg_temp.fx('b', 'program'), current_date) $$,
  'start_program still materializes b''s own program');

select * from finish();
rollback;
