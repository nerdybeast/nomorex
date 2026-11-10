-- AI import cleanup (#87): what ai_import_sweep() changes and which upload
-- folders it hands to the ai-import-cleanup function to empty. Fixtures belong
-- to the seeded a@a.com and b@b.com.
--
--   supabase test db        # local stack only; never --linked
begin;
create extension if not exists pgtap with schema extensions;
select plan(18);

create temp table t on commit drop as
select (select id from auth.users where email = 'a@a.com') as a_id,
       (select id from auth.users where email = 'b@b.com') as b_id;

-- One row per import: who owns it and a fresh import id.
create temp table imp (label text primary key, user_id uuid, import_id uuid default gen_random_uuid())
on commit drop;
insert into imp (label, user_id)
select label, case when label like 'b_%' then b_id else a_id end
from t, unnest(array[
  'accepted', 'discarded', 'ready_recent', 'b_ready_old', 'failed_old',
  'processing', 'b_stuck', 'orphan_old', 'orphan_recent', 'rerun'
]) label;

grant select on imp to service_role;

create function pg_temp.imp(p_label text) returns uuid language sql as $$
  select import_id from imp where label = p_label
$$;

create function pg_temp.job(p_label text) returns public.ai_import_jobs language sql as $$
  select j.* from public.ai_import_jobs j join imp using (import_id)
  where imp.label = p_label and j.status <> 'replaced'
$$;

-- Jobs. started/finished times are relative to now.
insert into public.ai_import_jobs (user_id, import_id, status, failure_code, started_at, finished_at)
select i.user_id, i.import_id, v.status, v.failure_code,
       now() - v.started_ago, now() - v.finished_ago
from imp i
join (values
  ('accepted', 'accepted', null, interval '1 day', interval '1 day'),
  ('discarded', 'discarded', null, interval '1 day', interval '1 day'),
  ('ready_recent', 'ready', null, interval '2 days', interval '2 days'),
  ('b_ready_old', 'ready', null, interval '8 days', interval '8 days'),
  ('failed_old', 'failed', 'timeout', interval '9 days', interval '9 days'),
  ('processing', 'processing', null, interval '10 seconds', null),
  ('b_stuck', 'processing', null, interval '1 hour', null),
  -- A re-run: the old run is replaced, the current one is fresh.
  ('rerun', 'replaced', null, interval '10 days', interval '10 days'),
  ('rerun', 'ready', null, interval '1 day', interval '1 day')
) v(label, status, failure_code, started_ago, finished_ago) on v.label = i.label;

insert into public.ai_import_results (job_id, user_id, payload)
select j.id, j.user_id, '{"type":"workout"}'::jsonb
from public.ai_import_jobs j join imp using (import_id)
where j.status = 'ready';

-- Two files per import; the orphans have no job.
insert into storage.objects (bucket_id, name, created_at)
select 'ai-imports', i.user_id || '/' || i.import_id || '/page-' || n || '.jpg',
       now() - case i.label when 'orphan_old' then interval '8 days'
                            when 'orphan_recent' then interval '1 day'
                            else interval '1 day' end
from imp i, generate_series(1, 2) n;

-- ---------------------------------------------------------------------------
-- Privileges
-- ---------------------------------------------------------------------------

select ok(not has_function_privilege('anon', 'public.ai_import_sweep()', 'execute'),
  'anon cannot run the sweep');
select ok(not has_function_privilege('authenticated', 'public.ai_import_sweep()', 'execute'),
  'signed-in users cannot run the sweep');
select ok(has_function_privilege('service_role', 'public.ai_import_sweep()', 'execute'),
  'service_role can run the sweep');

-- ---------------------------------------------------------------------------
-- The sweep
-- ---------------------------------------------------------------------------

set local role service_role;
-- Scoped to this test's imports, so other local data can't affect it.
create temp table swept on commit drop as
select * from public.ai_import_sweep() s where s.import_id in (select import_id::text from imp);
reset role;

select set_eq(
  $$ select user_id, import_id from swept $$,
  $$ select user_id::text, import_id::text from imp
     where label in ('accepted', 'discarded', 'b_ready_old', 'failed_old', 'orphan_old') $$,
  'returns the folders of finished, abandoned and orphaned imports, across users');

select is((select count(*)::int from swept), 5, 'each folder once, not once per file');

select is((pg_temp.job('b_ready_old')).status, 'discarded', 'a ready import untouched for 7 days is discarded');
select is((pg_temp.job('failed_old')).status, 'discarded', 'an old failed import is discarded');
select is(
  (select count(*)::int from public.ai_import_results r join public.ai_import_jobs j on j.id = r.job_id
   where j.import_id = pg_temp.imp('b_ready_old')),
  0, 'and its result is deleted');

select is((pg_temp.job('ready_recent')).status, 'ready', 'a recent ready import is left for review');
select is(
  (select count(*)::int from public.ai_import_results r join public.ai_import_jobs j on j.id = r.job_id
   where j.import_id = pg_temp.imp('ready_recent')),
  1, 'with its result');
select is((pg_temp.job('rerun')).status, 'ready', 'a re-run is judged by its current run, not the replaced one');

select is((pg_temp.job('processing')).status, 'processing', 'a running import is left alone');
select is((pg_temp.job('b_stuck')).status, 'failed', 'an import stuck past the longest run is failed');
select is((pg_temp.job('b_stuck')).failure_code, 'abandoned', 'as abandoned');
select ok(not (pg_temp.job('b_stuck')).counts_toward_limits, 'and not counted');
select ok(
  not exists (select 1 from swept where import_id = pg_temp.imp('b_stuck')::text),
  'its files are kept for now, so it can still be re-run');

select is(
  (select count(*)::int from public.ai_import_jobs j join imp using (import_id)),
  9, 'no job row is deleted: the caps count them');

-- A second run changes nothing new and still returns the same folders, which
-- is how a failed deletion is retried.
set local role service_role;
select set_eq(
  $$ select * from public.ai_import_sweep() s where s.import_id in (select import_id::text from imp) $$,
  $$ select * from swept $$,
  'running it again retries the same folders');
reset role;

select * from finish();
rollback;
