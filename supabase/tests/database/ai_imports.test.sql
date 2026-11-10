-- AI import foundation (#81): who can see and change import data, how the
-- limits are enforced, and how a job moves between states. Runs as the seeded
-- a@a.com (owner) and b@b.com (other).
--
--   supabase test db        # local stack only; never --linked
begin;
create extension if not exists pgtap with schema extensions;
select plan(77);

-- ---------------------------------------------------------------------------
-- Helpers and fixtures
-- ---------------------------------------------------------------------------

create temp table t on commit drop as
select (select id from auth.users where email = 'a@a.com') as owner_id,
       (select id from auth.users where email = 'b@b.com') as other_id;
grant select on t to authenticated;

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$;

select results_eq(
  $$ select daily_limit, monthly_limit, uncounted_failure_daily_limit, max_images,
            max_pdf_pages, max_image_bytes, max_pdf_bytes
     from public.ai_import_limits $$,
  $$ values (5, 30, 10, 8, 10, 7000000::bigint, 20000000::bigint) $$,
  'limits start at the agreed caps');

-- Generous limits, so each section only trips the one it is testing.
update public.ai_import_limits set
  enabled = true, daily_limit = 100, monthly_limit = 100,
  uncounted_failure_daily_limit = 100;

insert into public.ai_import_consents (user_id) select owner_id from t;

-- ---------------------------------------------------------------------------
-- Schema
-- ---------------------------------------------------------------------------

select ok(not (select public from storage.buckets where id = 'ai-imports'), 'bucket is private');
select is((select file_size_limit from storage.buckets where id = 'ai-imports'),
  20000000::bigint, 'bucket has a size limit');
select is((select allowed_mime_types from storage.buckets where id = 'ai-imports'),
  array['image/jpeg', 'image/png', 'image/webp', 'application/pdf'],
  'bucket allows exactly the four accepted types');

select is(
  (select count(*)::int from pg_publication_tables
   where pubname = 'supabase_realtime' and tablename = 'ai_import_jobs'),
  1, 'job status is published to Realtime');
select is(
  (select count(*)::int from pg_publication_tables
   where pubname = 'supabase_realtime' and tablename = 'ai_import_results'),
  0, 'results are not published to Realtime');

select col_default_is('public', 'ai_import_limits', 'enabled', 'false',
  'imports are off until launch');
select col_default_is('public', 'workouts', 'is_imported', 'false',
  'existing workouts are not marked imported');
select col_default_is('public', 'programs', 'is_imported', 'false',
  'existing programs are not marked imported');

select throws_ok(
  $$ insert into public.ai_import_limits (id) values (false) $$,
  '23514', null, 'limits table cannot hold a second row');

-- The constraint is what holds under concurrency. ai_imports_concurrency.test.sql
-- exercises two real connections.
insert into public.ai_import_jobs (id, user_id, import_id)
select '10000000-0000-4000-8000-000000000001'::uuid, other_id, gen_random_uuid() from t;
select throws_ok(
  format($$ insert into public.ai_import_jobs (user_id, import_id)
            values (%L, gen_random_uuid()) $$, (select other_id from t)),
  '23505', null, 'a user cannot hold two processing jobs');
delete from public.ai_import_jobs where id = '10000000-0000-4000-8000-000000000001';

select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname like 'ai\_import\_%'
     and has_function_privilege('anon', p.oid, 'execute')),
  0, 'signed-out callers cannot execute any import function');

-- ---------------------------------------------------------------------------
-- Consent
-- ---------------------------------------------------------------------------

select pg_temp.act_as((select other_id from t));
select is((select public.ai_import_check() ->> 'reason'), 'consent_required',
  'check asks for consent first');
select throws_like(
  $$ select public.ai_import_start(gen_random_uuid()) $$,
  'consent_required:%', 'start refuses a user who has not accepted the notice');
select is((select count(*)::int from public.ai_import_consents), 0,
  'a user cannot see another user''s consent');
select throws_ok(
  format($$ insert into public.ai_import_consents (user_id) values (%L) $$, (select owner_id from t)),
  '42501', null, 'a user cannot record consent for someone else');
select throws_ok(
  format($$ insert into public.ai_import_consents (user_id, accepted_at)
            values (%L, '2020-01-01') $$, (select other_id from t)),
  '42501', null, 'a user cannot choose their own acceptance time');
select lives_ok(
  format($$ insert into public.ai_import_consents (user_id) values (%L) $$, (select other_id from t)),
  'a user can record their own consent');
select is((select public.ai_import_check() ->> 'allowed'), 'true',
  'after consent the user may start');

-- ---------------------------------------------------------------------------
-- A job's life, and isolation between users
-- ---------------------------------------------------------------------------

select pg_temp.act_as((select owner_id from t));
create temp table job on commit drop as
select public.ai_import_start('20000000-0000-4000-8000-000000000001'::uuid, 'program') as id;
grant select on job to authenticated;

select is((select status from public.ai_import_jobs where id = (select id from job)),
  'processing', 'start creates a processing job');
select is((select requested_type from public.ai_import_jobs where id = (select id from job)),
  'program', 'start records the requested type');
select is((select public.ai_import_check() ->> 'reason'), 'active_import',
  'check reports the running job');
select throws_like(
  $$ select public.ai_import_start(gen_random_uuid()) $$,
  'active_import:%', 'a second job is refused while one runs');

select throws_like(
  format($$ select public.ai_import_finish(%L, 'workout', null, null) $$, (select id from job)),
  'invalid_input:%', 'finish needs either a result or a failure code');
select throws_like(
  format($$ select public.ai_import_finish(%L, 'nonsense', '{}'::jsonb) $$, (select id from job)),
  'invalid_input:%', 'finish refuses an unknown type');
select throws_like(
  format($$ select public.ai_import_finish(%L, null, null, 'abandoned') $$, (select id from job)),
  'invalid_input:%', 'only the database can record a job as abandoned');
select throws_like(
  format($$ select public.ai_import_finish(%L, 'workout',
            jsonb_build_object('x', repeat('a', 1048577))) $$, (select id from job)),
  'result_too_large:%', 'finish refuses an oversized result');

select pg_temp.act_as((select other_id from t));
select is((select count(*)::int from public.ai_import_jobs), 0,
  'another user cannot see the job');
select throws_like(
  format($$ select public.ai_import_finish(%L, 'program', '{}'::jsonb) $$, (select id from job)),
  'not_found:%', 'another user cannot finish the job');

select pg_temp.act_as((select owner_id from t));
select lives_ok(
  format($$ select public.ai_import_finish(%L, 'program', '{"weeks": []}'::jsonb, null, 10, 20, 'test-model') $$,
         (select id from job)),
  'the owner can finish with a result');
select results_eq(
  format($$ select status, detected_type, counts_toward_limits, input_tokens, output_tokens
            from public.ai_import_jobs where id = %L $$, (select id from job)),
  $$ values ('ready'::text, 'program'::text, true, 10, 20) $$,
  'finish records the outcome and usage');
select ok((select finished_at is not null from public.ai_import_jobs where id = (select id from job)),
  'finish records the finish time');
select is((select payload from public.ai_import_results where job_id = (select id from job)),
  '{"weeks": []}'::jsonb, 'the owner can read the result');
select throws_like(
  format($$ select public.ai_import_finish(%L, 'program', '{}'::jsonb) $$, (select id from job)),
  'not_processing:%', 'a job can only finish once');

select pg_temp.act_as((select other_id from t));
select is((select count(*)::int from public.ai_import_results), 0,
  'another user cannot read the result');
select throws_like(
  format($$ select public.ai_import_claim(%L) $$, (select id from job)),
  'not_found:%', 'another user cannot claim the job');
select throws_like(
  format($$ select public.ai_import_discard(%L) $$, (select id from job)),
  'not_found:%', 'another user cannot discard the job');

-- Direct writes, even to the caller's own rows.
select pg_temp.act_as((select owner_id from t));
select throws_ok(
  format($$ insert into public.ai_import_jobs (user_id, import_id) values (%L, gen_random_uuid()) $$,
         (select owner_id from t)),
  '42501', null, 'users cannot insert jobs directly');
select throws_ok(
  $$ update public.ai_import_jobs set counts_toward_limits = false $$,
  '42501', null, 'users cannot update jobs directly');
select throws_ok($$ delete from public.ai_import_jobs $$,
  '42501', null, 'users cannot delete jobs directly');
select throws_ok(
  format($$ insert into public.ai_import_results (job_id, user_id, payload) values (%L, %L, '{}') $$,
         (select id from job), (select owner_id from t)),
  '42501', null, 'users cannot write results directly');
select throws_ok($$ update public.ai_import_limits set daily_limit = 1000 $$,
  '42501', null, 'users cannot change the limits');

-- ---------------------------------------------------------------------------
-- Re-run, accept, discard
-- ---------------------------------------------------------------------------

create temp table rerun on commit drop as
select public.ai_import_start('20000000-0000-4000-8000-000000000001'::uuid, 'workout') as id;
grant select on rerun to authenticated;

select is((select status from public.ai_import_jobs where id = (select id from job)),
  'replaced', 'a re-run replaces the earlier run');
select is((select count(*)::int from public.ai_import_results where job_id = (select id from job)),
  0, 'a re-run removes the earlier result');
select ok((select counts_toward_limits from public.ai_import_jobs where id = (select id from job)),
  'the replaced run still counts');

select public.ai_import_finish((select id from rerun), 'workout', '{"a": 1}'::jsonb);
select is(public.ai_import_claim((select id from rerun)) ->> 'status', 'ready',
  'claim returns a ready job');

reset role;
insert into public.workouts (id, user_id, title, date)
select '30000000-0000-4000-8000-000000000001'::uuid, owner_id, 'pgTAP import', current_date from t;
insert into public.workouts (id, user_id, title, date)
select '30000000-0000-4000-8000-000000000002'::uuid, other_id, 'pgTAP other', current_date from t;
select pg_temp.act_as((select owner_id from t));

select throws_like(
  format($$ select public.ai_import_mark_accepted(%L, '30000000-0000-4000-8000-000000000002') $$,
         (select id from rerun)),
  'not_found:%', 'a job cannot be accepted onto someone else''s workout');
select public.ai_import_mark_accepted((select id from rerun), '30000000-0000-4000-8000-000000000001');
select is(public.ai_import_claim((select id from rerun)) ->> 'workout_id',
  '30000000-0000-4000-8000-000000000001',
  'a second claim returns the existing workout');
select is((select count(*)::int from public.ai_import_results where job_id = (select id from rerun)),
  0, 'accepting removes the result');
select throws_like(
  format($$ select public.ai_import_mark_accepted(%L, '30000000-0000-4000-8000-000000000001') $$,
         (select id from rerun)),
  'not_ready:%', 'a job can only be accepted once');
select throws_like(
  $$ select public.ai_import_start('20000000-0000-4000-8000-000000000001'::uuid) $$,
  'import_closed:%', 'an accepted import cannot be re-run');

create temp table discarded on commit drop as
select public.ai_import_start('20000000-0000-4000-8000-000000000002'::uuid) as id;
grant select on discarded to authenticated;
select public.ai_import_finish((select id from discarded), 'workout', '{"a": 1}'::jsonb);
select public.ai_import_discard((select id from discarded));
select public.ai_import_discard((select id from discarded));
select is((select status from public.ai_import_jobs where id = (select id from discarded)),
  'discarded', 'discard closes the job, and repeating it is harmless');
select is((select count(*)::int from public.ai_import_results where job_id = (select id from discarded)),
  0, 'discarding removes the result');

-- ---------------------------------------------------------------------------
-- Off switch: new imports refused, a running one still finishes
-- ---------------------------------------------------------------------------

create temp table running on commit drop as
select public.ai_import_start(gen_random_uuid()) as id;
grant select on running to authenticated;

reset role;
update public.ai_import_limits set enabled = false;
select pg_temp.act_as((select owner_id from t));
select is((select public.ai_import_check() ->> 'reason'), 'imports_disabled',
  'the off switch is reported');
select throws_like($$ select public.ai_import_start(gen_random_uuid()) $$,
  'imports_disabled:%', 'the off switch refuses new imports');
select lives_ok(
  format($$ select public.ai_import_finish(%L, null, null, 'timeout') $$, (select id from running)),
  'a running import can still finish while switched off');

-- ---------------------------------------------------------------------------
-- Caps, from a clean slate
-- ---------------------------------------------------------------------------

reset role;
delete from public.ai_import_jobs where user_id = (select owner_id from t);
update public.ai_import_limits set enabled = true, daily_limit = 2, monthly_limit = 100,
  uncounted_failure_daily_limit = 2;

-- Just outside each window, so these must not count.
insert into public.ai_import_jobs (user_id, import_id, status, started_at, finished_at)
select owner_id, gen_random_uuid(), 'ready',
       (date_trunc('month', now() at time zone 'UTC') at time zone 'UTC') - interval '1 second', now()
from t;

select pg_temp.act_as((select owner_id from t));
create temp table counted on commit drop as
select public.ai_import_start(gen_random_uuid()) as id;
grant select on counted to authenticated;
select public.ai_import_finish((select id from counted), null, null, 'no_workout_found');
select ok((select counts_toward_limits from public.ai_import_jobs where id = (select id from counted)),
  '"no workout found" counts as an import');

select public.ai_import_finish(public.ai_import_start(gen_random_uuid()), 'workout', '{}'::jsonb);
select is((select public.ai_import_check() ->> 'reason'), 'daily_limit',
  'the daily cap is reported');
select ok(
  (select (public.ai_import_check() ->> 'resets_at')::timestamptz
     = (date_trunc('day', now() at time zone 'UTC') + interval '1 day') at time zone 'UTC'),
  'the daily cap resets at the next UTC midnight');
select throws_like($$ select public.ai_import_start(gen_random_uuid()) $$,
  'daily_limit:%', 'the daily cap refuses a start');

reset role;
update public.ai_import_limits set daily_limit = 100, monthly_limit = 2;
select pg_temp.act_as((select owner_id from t));
select throws_like($$ select public.ai_import_start(gen_random_uuid()) $$,
  'monthly_limit:%', 'the monthly cap refuses a start');

-- ---------------------------------------------------------------------------
-- Dead jobs and the uncounted-failure cap
-- ---------------------------------------------------------------------------

reset role;
delete from public.ai_import_jobs where user_id = (select owner_id from t);
-- Backdated by seconds, with a short limit to match: the job has to be dead yet
-- still fall on today's UTC date for the failure cap below to count it.
update public.ai_import_limits set daily_limit = 2, monthly_limit = 100,
  uncounted_failure_daily_limit = 3, max_job_seconds = 1;
insert into public.ai_import_jobs (id, user_id, import_id, started_at)
select '10000000-0000-4000-8000-000000000002'::uuid, owner_id, gen_random_uuid(), now() - interval '2 seconds'
from t;

select pg_temp.act_as((select owner_id from t));
select is((select public.ai_import_check() ->> 'allowed'), 'true',
  'a dead job does not block the check');
select is((select (public.ai_import_check() ->> 'daily_used')::int), 0,
  'a dead job is not counted by the check');

create temp table after_dead on commit drop as
select public.ai_import_start('20000000-0000-4000-8000-000000000003'::uuid) as id;
grant select on after_dead to authenticated;
select results_eq(
  $$ select status, failure_code, counts_toward_limits from public.ai_import_jobs
     where id = '10000000-0000-4000-8000-000000000002' $$,
  $$ values ('failed'::text, 'abandoned'::text, false) $$,
  'start marks a dead job failed without counting it');

select public.ai_import_finish((select id from after_dead), null, null, 'timeout');
select ok(not (select counts_toward_limits from public.ai_import_jobs where id = (select id from after_dead)),
  'a failure on our side does not count');
select is((select (public.ai_import_check() ->> 'daily_used')::int), 0,
  'uncounted failures leave the daily cap alone');

-- Re-running must not wipe the failure: this is the third, with one replaced.
select public.ai_import_finish(
  public.ai_import_start('20000000-0000-4000-8000-000000000003'::uuid), null, null, 'model_error');
select is((select public.ai_import_check() ->> 'reason'), 'failure_limit',
  'uncounted failures have their own cap, and re-runs do not erase them');
select throws_like($$ select public.ai_import_start(gen_random_uuid()) $$,
  'failure_limit:%', 'the uncounted-failure cap refuses a start');

-- ---------------------------------------------------------------------------
-- Storage
-- ---------------------------------------------------------------------------

reset role;
delete from public.ai_import_jobs where user_id = (select owner_id from t);
update public.ai_import_limits set daily_limit = 100, uncounted_failure_daily_limit = 100;

create function pg_temp.upload_sql(p_path text) returns text language sql as $$
  select format($q$ insert into storage.objects (bucket_id, name) values ('ai-imports', %L) $q$, p_path);
$$;

select pg_temp.act_as((select owner_id from t));
select lives_ok(
  pg_temp.upload_sql((select owner_id from t)::text || '/20000000-0000-4000-8000-000000000004/page1.jpg'),
  'a user can upload to their own import folder');
select throws_ok(
  pg_temp.upload_sql((select other_id from t)::text || '/20000000-0000-4000-8000-000000000004/page1.jpg'),
  '42501', null, 'a user cannot upload to another user''s folder');
select throws_ok(
  pg_temp.upload_sql((select owner_id from t)::text || '/page1.jpg'),
  '42501', null, 'an upload must sit inside an import folder');
select throws_ok(
  pg_temp.upload_sql((select owner_id from t)::text || '/not-a-uuid/page1.jpg'),
  '42501', null, 'the import folder must be an id');

select is(
  (select count(*)::int from storage.objects where bucket_id = 'ai-imports'),
  1, 'the owner can see their file');

select pg_temp.act_as((select other_id from t));
select is(
  (select count(*)::int from storage.objects where bucket_id = 'ai-imports'),
  0, 'another user cannot see the file');

reset role;
delete from public.ai_import_consents where user_id = (select other_id from t);
select pg_temp.act_as((select other_id from t));
select throws_ok(
  pg_temp.upload_sql((select other_id from t)::text || '/20000000-0000-4000-8000-000000000005/page1.jpg'),
  '42501', null, 'nothing can be uploaded before the notice is accepted');

select pg_temp.act_as((select owner_id from t));
select public.ai_import_start(gen_random_uuid());
select throws_ok(
  pg_temp.upload_sql((select owner_id from t)::text || '/20000000-0000-4000-8000-000000000006/page1.jpg'),
  '42501', null, 'nothing can be uploaded while an import runs');

reset role;
delete from public.ai_import_jobs where user_id = (select owner_id from t);
update public.ai_import_limits set enabled = false;
select pg_temp.act_as((select owner_id from t));
select throws_ok(
  pg_temp.upload_sql((select owner_id from t)::text || '/20000000-0000-4000-8000-000000000007/page1.jpg'),
  '42501', null, 'nothing can be uploaded while imports are switched off');

select * from finish();
rollback;
