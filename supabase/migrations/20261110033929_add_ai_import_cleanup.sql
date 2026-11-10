-- Daily cleanup of AI imports (#87, part of #79). Additive: nothing calls it
-- until the ai-import-cleanup function is deployed and scheduled.
--
-- ai_import_sweep() does the database half of the cleanup and returns the
-- upload folders whose files should go. The ai-import-cleanup edge function
-- deletes those through the Storage API, since removing storage.objects rows
-- in SQL would leave the stored files behind.
--
-- Only service_role may call it: it acts on every user's imports, and a
-- scheduled job has no user session. That privilege lives in the separate
-- cleanup function, never in the `ai` function, which handles untrusted files.

create or replace function public.ai_import_sweep()
returns table (user_id text, import_id text)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_retention constant interval := interval '7 days';
begin
  -- A worker that died mid-run never records its outcome. Same rule as
  -- ai_import_start applies per user: failed, and not counted.
  update public.ai_import_jobs j
  set status = 'failed',
      failure_code = 'abandoned',
      counts_toward_limits = false,
      finished_at = now()
  from public.ai_import_limits l
  where j.status = 'processing'
    and j.started_at < now() - make_interval(secs => l.max_job_seconds);

  -- Finished but never reviewed or dismissed: treat as discarded. The row
  -- stays, because the caps count it.
  update public.ai_import_jobs j
  set status = 'discarded'
  where j.status in ('ready', 'failed')
    and coalesce(j.finished_at, j.started_at) < now() - v_retention;

  -- Only a ready job's result is still needed. The status transitions already
  -- delete the rest; this catches any left behind.
  delete from public.ai_import_results r
  using public.ai_import_jobs j
  where r.job_id = j.id
    and j.status <> 'ready';

  -- Folders to empty: those whose import is accepted or discarded (retrying
  -- any deletion the app couldn't finish), and those that never got a job
  -- and haven't been written to for the retention period. A modified client
  -- can upload without starting a job.
  return query
  with folders as (
    select
      (storage.foldername(o.name))[1] as user_part,
      (storage.foldername(o.name))[2] as import_part,
      max(o.created_at) as last_upload
    from storage.objects o
    where o.bucket_id = 'ai-imports'
    group by 1, 2
  )
  select f.user_part, f.import_part
  from folders f
  left join public.ai_import_jobs j
    on j.user_id::text = f.user_part
    and j.import_id::text = f.import_part
    and j.status <> 'replaced'
  where f.user_part is not null
    and f.import_part is not null
    and (
      j.status in ('accepted', 'discarded')
      or (j.id is null and f.last_upload < now() - v_retention)
    )
  order by 1, 2;
end;
$$;

-- Default privileges grant every routine to anon and authenticated.
revoke all on function public.ai_import_sweep() from public, anon, authenticated;
grant execute on function public.ai_import_sweep() to service_role;
