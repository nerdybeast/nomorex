-- Admin management of the official exercise catalog (20261114212947). a@a.com
-- is the seeded admin; non-admin and anon refusals are in admin.test.sql.
--
--   supabase test db        # local stack only; never --linked
begin;
create extension if not exists pgtap with schema extensions;
select plan(33);

create temp table u on commit drop as
select (select id from auth.users where email = 'a@a.com') as a,
       (select id from auth.users where email = 'b@b.com') as b,
       (select id from public.exercises where slug = 'back_squat') as squat,
       (select id from public.exercises where name = 'Dude Pulls' and not is_predefined) as dude_pulls,
       (select count(*) from public.exercises where is_predefined and retired_at is null) as active_count;
grant select on u to authenticated;

-- Audit rows this test wrote for one exercise (now() is the transaction start).
create function pg_temp.audits(p_action text, p_exercise uuid) returns integer
language sql as $$
  select count(*)::int from public.admin_audit_log
  where action = p_action and details ->> 'exercise_id' = p_exercise::text and created_at = now()
$$;
grant execute on function pg_temp.audits(text, uuid) to authenticated;

select set_config('request.jwt.claims', json_build_object('sub', (select a from u), 'role', 'authenticated')::text, true);
set local role authenticated;

-- ---------------------------------------------------------------------------
-- Listing
-- ---------------------------------------------------------------------------

select is((select total_count from public.admin_list_exercises() limit 1), (select active_count from u),
  'the active list counts every active official exercise');
select is((select count(*)::int from public.admin_list_exercises(null, true)), 0, 'nothing is retired yet');
select is((select array_agg(slug) from public.admin_list_exercises('c&j')), array['clean_and_jerk'], 'search matches an alias');
select ok(exists (select 1 from public.admin_list_exercises('power_clean_and_j') where slug = 'power_clean_and_jerk'),
  'search matches a slug');
select ok((select usage_count from public.admin_list_exercises('back squat') where slug = 'back_squat') > 0,
  'usage counts lifters who use the exercise');
select is((select usage_count from public.admin_list_exercises('box squat') where slug = 'box_squat'), 0::bigint,
  'an unused exercise has no usage');

-- ---------------------------------------------------------------------------
-- Creating
-- ---------------------------------------------------------------------------

select throws_like($$ select * from public.admin_create_exercise('Bad Slug', 'Bad Slug Lift') $$,
  'invalid_input: a slug is%', 'a malformed slug is refused');
select throws_like($$ select * from public.admin_create_exercise('blank_name', '   ') $$,
  'invalid_input: an exercise needs a name', 'a blank name is refused');
select throws_like($$ select * from public.admin_create_exercise('back_squat', 'Another Squat') $$,
  'duplicate: the slug back_squat is already taken%', 'a taken slug is refused');
select throws_like($$ select * from public.admin_create_exercise('cj_again', 'C&J') $$,
  'duplicate: "Clean & Jerk"%', 'a name another exercise answers to is refused');

create temp table created on commit drop as
select * from public.admin_create_exercise('dude_pull_machine', '  Dude Pull   Machine ', array['Dude Pulls']);
grant select on created to authenticated;

select is((select custom_name_count from created), 1::bigint,
  'creating reports lifters with a custom exercise of the same name');
select is((select name from public.exercises where id = (select id from created)), 'Dude Pull Machine',
  'the new exercise is official, with its name tidied');
select is(pg_temp.audits('exercise_created', (select id from created)), 1, 'creating writes one audit row');

-- ---------------------------------------------------------------------------
-- Updating
-- ---------------------------------------------------------------------------

select lives_ok($$ select public.admin_update_exercise((select id from created), 'Dude Pull Station', array['Dude Pulls', 'Dude Pull Machine']) $$,
  'an admin can rename and set aliases');
select is((select aliases from public.exercises where id = (select id from created)), array['Dude Pulls', 'Dude Pull Machine'],
  'aliases are replaced');
select is((select slug from public.exercises where id = (select id from created)), 'dude_pull_machine',
  'the slug does not follow the name');
select lives_ok($$ select public.admin_update_exercise((select id from created), 'Dude Pull Station', array['Dude Pulls', 'Dude Pull Machine']) $$,
  'saving with no change works');
select is(pg_temp.audits('exercise_updated', (select id from created)), 1, 'only the real change was audited');
select throws_like($$ select public.admin_update_exercise((select dude_pulls from u), 'Mine Now') $$,
  'not_found:%', 'a custom exercise cannot be edited through the admin functions');
select throws_like($$ select public.admin_update_exercise((select id from created), 'Back Squat') $$,
  'duplicate:%', 'a rename onto another exercise''s name is refused');

-- ---------------------------------------------------------------------------
-- Retiring and restoring
-- ---------------------------------------------------------------------------

select lives_ok($$ select public.admin_set_exercise_retired((select id from created), true) $$, 'an admin can retire');
select lives_ok($$ select public.admin_set_exercise_retired((select id from created), true) $$, 'retiring twice is a no-op');
select is(pg_temp.audits('exercise_retired', (select id from created)), 1, 'retiring is audited once');
select is((select slug from public.admin_list_exercises(null, true)), 'dude_pull_machine', 'it moves to the retired list');

-- Its name is free again, so another exercise can take it; then restoring clashes.
create temp table clash on commit drop as
select * from public.admin_create_exercise('dude_pull_station', 'Dude Pull Station');
grant select on clash to authenticated;
select throws_like($$ select public.admin_set_exercise_retired((select id from created), false) $$,
  'duplicate:%', 'restoring is refused while its name is taken');
select lives_ok($$ select public.admin_delete_exercise((select id from clash)) $$, 'an unused exercise can be deleted');
select lives_ok($$ select public.admin_set_exercise_retired((select id from created), false) $$, 'then it can be restored');
select is(pg_temp.audits('exercise_restored', (select id from created)), 1, 'restoring is audited');

-- ---------------------------------------------------------------------------
-- Deleting
-- ---------------------------------------------------------------------------

select throws_like($$ select public.admin_delete_exercise((select squat from u)) $$,
  'in_use: Back Squat is used by % lifter(s). Retire it instead.', 'an exercise in use cannot be deleted');
select is(pg_temp.audits('exercise_deleted', (select id from clash)), 1, 'deleting is audited');
select is((select count(*)::int from public.exercises where id = (select id from clash)), 0, 'the deleted row is gone');

-- ---------------------------------------------------------------------------
-- Export
-- ---------------------------------------------------------------------------

select ok(public.admin_export_exercises() like '-- The official exercise catalog%', 'the export is the catalog file');
select ok(strpos(public.admin_export_exercises(),
  $x$  ('dude_pull_machine', 'Dude Pull Station', array['Dude Pulls', 'Dude Pull Machine'], null)$x$) > 0,
  'the export includes changes made here');

select * from finish();
rollback;
