-- The official exercise catalog (20261114202746): slugs, aliases, retiring,
-- the shared name rule, alias-aware matching, and basis foreign keys that
-- refuse a delete instead of silently re-pointing sets.
--
--   supabase test db        # local stack only; never --linked
begin;
create extension if not exists pgtap with schema extensions;
select plan(39);

create temp table t on commit drop as
select (select id from auth.users where email = 'a@a.com') as a,
       (select id from auth.users where email = 'b@b.com') as b,
       (select id from public.exercises where slug = 'clean_and_jerk') as cj,
       (select id from public.exercises where slug = 'back_squat') as squat,
       (select id from public.exercises where name = 'Dude Pulls' and not is_predefined) as dude_pulls;
grant select on t to authenticated;

-- ---------------------------------------------------------------------------
-- normalize_exercise_name. The Dart (normalize_exercise_name_test.dart) and
-- TypeScript (normalize_test.ts) copies run these same cases.
-- ---------------------------------------------------------------------------

select is(public.normalize_exercise_name('  Clean   &  Jerk '), 'clean & jerk', 'collapses and trims spaces, lowercases');
select is(public.normalize_exercise_name(E'BACK\tSquat\n'), 'back squat', 'tabs and newlines count as spaces');
select is(public.normalize_exercise_name('Pull-Up'), 'pull-up', 'punctuation is kept');
select is(public.normalize_exercise_name('   '), '', 'blank stays blank');
select is(public.exercise_match_keys('Clean & Jerk', array['C&J', 'clean & jerk ']),
  array['c&j', 'clean & jerk'], 'match keys are the name plus aliases, normalized and deduplicated');

-- ---------------------------------------------------------------------------
-- The catalog seed
-- ---------------------------------------------------------------------------

select isnt((select cj from t), null, 'the catalog seeds clean_and_jerk');
select is((select count(*)::int from public.exercises where is_predefined and slug is null), 0,
  'every official exercise has a slug');
select is((select aliases from public.exercises where slug = 'clean_and_jerk'), array['C&J', 'Clean and Jerk'],
  'catalog aliases are loaded');

-- ---------------------------------------------------------------------------
-- Row shape (as superuser, so only constraints and the trigger apply)
-- ---------------------------------------------------------------------------

select throws_ok($$ insert into public.exercises (name, is_predefined) values ('No Slug Lift', true) $$,
  '23514', null, 'an official exercise needs a slug');
select throws_ok($$ insert into public.exercises (slug, name, is_predefined) values ('Bad-Slug', 'Bad Slug Lift', true) $$,
  '23514', null, 'a slug is lowercase words joined by underscores');
select throws_ok($$ insert into public.exercises (slug, name, is_predefined, user_id) select 'mine', 'Mine', false, a from t $$,
  '23514', null, 'a custom exercise has no slug');
select throws_ok($$ insert into public.exercises (name, aliases, is_predefined, user_id) select 'Mine', array['M'], false, a from t $$,
  '23514', null, 'a custom exercise has no aliases');
select throws_ok($$ insert into public.exercises (name, retired_at, is_predefined, user_id) select 'Mine', now(), false, a from t $$,
  '23514', null, 'a custom exercise cannot be retired');
select throws_ok($$ insert into public.exercises (slug, name, is_predefined) values ('pgtap_blank', '   ', true) $$,
  '23514', null, 'a name cannot be blank');
select throws_ok($$ update public.exercises set slug = 'clean_jerk' where slug = 'clean_and_jerk' $$,
  'P0001', 'invalid_input: an exercise''s slug can''t be changed', 'a slug is permanent');
select throws_ok($$ insert into public.exercises (slug, name, is_predefined) values ('back_squat', 'Another Squat', true) $$,
  '23505', null, 'slugs are unique');

-- Names and aliases are tidied on write.
insert into public.exercises (slug, name, aliases, is_predefined)
values ('zercher_squat', '  Zercher   Squat ', array[' ZS ', 'zs', '', 'zercher squat', 'Zercher'], true);
select is((select name from public.exercises where slug = 'zercher_squat'), 'Zercher Squat', 'the name is tidied');
select is((select aliases from public.exercises where slug = 'zercher_squat'), array['ZS', 'Zercher'],
  'aliases are trimmed, and blanks, repeats and the name itself are dropped');

-- ---------------------------------------------------------------------------
-- One name, one active official exercise
-- ---------------------------------------------------------------------------

select throws_ok($$ insert into public.exercises (slug, name, is_predefined) values ('cj', 'C&J', true) $$,
  'P0001', 'duplicate: "Clean & Jerk" already uses one of these names or aliases',
  'a new name cannot be another exercise''s alias');
select throws_ok($$ insert into public.exercises (slug, name, aliases, is_predefined) values ('pgtap_sq', 'PGTAP Squat', array['  SQUAT'], true) $$,
  'P0001', null, 'a new alias cannot be another exercise''s alias');
select throws_ok($$ update public.exercises set name = 'Back Squat' where slug = 'front_squat' $$,
  'P0001', null, 'a rename cannot take another exercise''s name');
select lives_ok($$ insert into public.exercises (slug, name, retired_at, is_predefined) values ('old_back_squat', 'Back Squat', now(), true) $$,
  'a retired exercise may share a name with an active one');
select throws_ok($$ update public.exercises set retired_at = null where slug = 'old_back_squat' $$,
  'P0001', null, 'restoring it is refused while the name is taken');
select lives_ok($$ update public.exercises set name = 'Back Squat', aliases = array['Squat'] where slug = 'back_squat' $$,
  'an exercise may keep its own name and aliases');

-- ---------------------------------------------------------------------------
-- Clients cannot write official exercises
-- ---------------------------------------------------------------------------

select set_config('request.jwt.claims', json_build_object('sub', (select b from t), 'role', 'authenticated')::text, true);
set local role authenticated;

select throws_ok($$ insert into public.exercises (slug, name, is_predefined) values ('b_lift', 'B Lift', true) $$,
  '42501', null, 'a user cannot create an official exercise');
update public.exercises set name = 'Hacked' where slug = 'clean_and_jerk';
select is((select name from public.exercises where slug = 'clean_and_jerk'), 'Clean & Jerk',
  'a user cannot rename an official exercise');

-- ---------------------------------------------------------------------------
-- Matching (as b)
-- ---------------------------------------------------------------------------

select is(public.find_exercise_for_user('c&j'), (select cj from t), 'an alias finds the official exercise');
select is(public.find_exercise_for_user('  CLEAN   and jerk '), (select cj from t), 'aliases match by the same rule');
select is(public.find_exercise_for_user('dude pulls'), (select dude_pulls from t), 'a custom exercise is found by name');
select is(public.find_exercise_for_user('Not A Lift'), null, 'no match is null');
select is(public.ai_import_resolve_exercise('C&J', null), (select cj from t),
  'AI import resolves an alias to the official exercise');

reset role;
select set_config('request.jwt.claims', json_build_object('sub', (select a from t), 'role', 'authenticated')::text, true);
set local role authenticated;

select is(public.find_exercise_for_user('dude pulls'), null, 'another user''s custom exercise is not in the caller''s catalog');

reset role;
-- A retired official exercise still matches, after any active one.
insert into public.exercises (slug, name, retired_at, is_predefined) values ('pgtap_retired', 'PGTAP Retired Lift', now(), true);
-- And b's custom "Dude Pulls" becomes reachable for a through an official alias.
insert into public.exercises (slug, name, aliases, is_predefined) values ('dude_pull_machine', 'Dude Pull Machine', array['Dude Pulls'], true);
select set_config('request.jwt.claims', json_build_object('sub', (select a from t), 'role', 'authenticated')::text, true);
set local role authenticated;

select is(public.find_exercise_for_user('pgtap retired lift'), (select id from public.exercises where slug = 'pgtap_retired'),
  'a retired official exercise still matches by name');
select is(public.find_exercise_for_user('back squat'), (select squat from t),
  'the active official exercise wins over a retired one of the same name');
select is(public.map_exercise_for_viewer((select dude_pulls from t)),
  (select id from public.exercises where slug = 'dude_pull_machine'),
  'copying another user''s custom exercise maps it to the official one with that alias');
select is(public.map_exercise_for_viewer((select cj from t)), (select cj from t),
  'an official exercise maps to itself');

reset role;

-- ---------------------------------------------------------------------------
-- Basis foreign keys refuse the delete
-- ---------------------------------------------------------------------------

insert into public.exercises (slug, name, is_predefined) values ('pgtap_basis_only', 'PGTAP Basis Only', true);
insert into public.workout_sets (workout_exercise_id, user_id, position, target_reps, weight_mode, percentage, basis_exercise_id)
select '8b3eaf4d-505c-416d-be9f-a0b1c2d3e4f5', b, 9, 3, 'percentage', 70,
       (select id from public.exercises where slug = 'pgtap_basis_only')
from t;
insert into public.program_sets (program_exercise_id, user_id, position, target_reps, weight_mode, percentage, basis_exercise_id)
select 'e1a27dc0-5e83-4f96-17be-9d3082f4b567', b, 9, 3, 'percentage', 70,
       (select id from public.exercises where slug = 'pgtap_basis_only')
from t;

select throws_ok($$ delete from public.exercises where slug = 'pgtap_basis_only' $$,
  '23503', null, 'an exercise used as a percentage basis cannot be deleted');
delete from public.program_sets where basis_exercise_id = (select id from public.exercises where slug = 'pgtap_basis_only');
select throws_ok($$ delete from public.exercises where slug = 'pgtap_basis_only' $$,
  '23503', null, 'a workout set''s basis alone also blocks it');
select lives_ok($$ delete from auth.users where email = 'b@b.com' $$,
  'deleting an account still cascades through its sets and custom exercises');

select * from finish();
rollback;
