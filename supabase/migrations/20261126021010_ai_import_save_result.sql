-- Save an AI import the app ran itself (Stage 2 of #182). Additive: the hosted
-- path keeps working, and nothing calls the new function until Stage 6.
--
-- With "bring your own AI" the app calls the lifter's own provider (or the
-- on-device model) and only stores the result here, so the review and accept
-- flow (Home's Review card, /ai-import/review/:jobId, ai_import_accept) works
-- unchanged. No model call runs on the project's account, so these runs need
-- no consent row, no uploaded files and no cap, and never use up the hosted
-- caps.

-- ---------------------------------------------------------------------------
-- Which pipeline ran the import
-- ---------------------------------------------------------------------------

alter table public.ai_import_jobs
  add column provider text not null default 'hosted'
    check (provider in ('hosted', 'anthropic', 'openai', 'gemini', 'on_device')),
  -- The caps are for the project's own spend. ai_import_check() also filters
  -- on provider; this keeps the flag honest for anything else that reads it.
  add constraint ai_import_jobs_only_hosted_counts
    check (provider = 'hosted' or not counts_toward_limits);

-- ---------------------------------------------------------------------------
-- Caps count hosted runs only
-- ---------------------------------------------------------------------------

-- Body unchanged from 20261109043825_add_ai_import_foundation.sql apart from
-- the provider filter on the job count.
create or replace function public.ai_import_check()
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_limits public.ai_import_limits%rowtype;
  v_day_start timestamptz := date_trunc('day', now() at time zone 'UTC') at time zone 'UTC';
  v_next_day timestamptz :=
    (date_trunc('day', now() at time zone 'UTC') + interval '1 day') at time zone 'UTC';
  v_month_start timestamptz := date_trunc('month', now() at time zone 'UTC') at time zone 'UTC';
  v_next_month timestamptz :=
    (date_trunc('month', now() at time zone 'UTC') + interval '1 month') at time zone 'UTC';
  v_dead_before timestamptz;
  v_active integer;
  v_daily integer;
  v_monthly integer;
  v_failures integer;
  v_reason text;
  v_resets_at timestamptz;
begin
  if v_user_id is null then
    raise exception 'not_authenticated: sign in required' using errcode = 'P0001';
  end if;

  select * into v_limits from public.ai_import_limits;
  if not found then
    return jsonb_build_object('allowed', false, 'reason', 'imports_disabled');
  end if;

  v_dead_before := now() - make_interval(secs => v_limits.max_job_seconds);

  -- Failed runs that were later replaced still count: status isn't consulted
  -- for the uncounted failures, or re-running would erase them.
  select
    count(*) filter (where j.status = 'processing' and j.started_at >= v_dead_before),
    count(*) filter (where j.started_at >= v_day_start and j.counts_toward_limits
      and not (j.status = 'processing' and j.started_at < v_dead_before)),
    count(*) filter (where j.started_at >= v_month_start and j.counts_toward_limits
      and not (j.status = 'processing' and j.started_at < v_dead_before)),
    count(*) filter (where j.started_at >= v_day_start and (
      (not j.counts_toward_limits and j.failure_code is not null)
      or (j.status = 'processing' and j.started_at < v_dead_before)
    ))
  into v_active, v_daily, v_monthly, v_failures
  from public.ai_import_jobs j
  where j.user_id = v_user_id
    and j.provider = 'hosted'
    and (j.started_at >= v_month_start or j.status = 'processing');

  if not v_limits.enabled then
    v_reason := 'imports_disabled';
  elsif not exists (
    select 1 from public.ai_import_consents c where c.user_id = v_user_id
  ) then
    v_reason := 'consent_required';
  elsif v_active > 0 then
    v_reason := 'active_import';
  elsif v_monthly >= v_limits.monthly_limit then
    v_reason := 'monthly_limit';
    v_resets_at := v_next_month;
  elsif v_daily >= v_limits.daily_limit then
    v_reason := 'daily_limit';
    v_resets_at := v_next_day;
  elsif v_failures >= v_limits.uncounted_failure_daily_limit then
    v_reason := 'failure_limit';
    v_resets_at := v_next_day;
  end if;

  return jsonb_build_object(
    'allowed', v_reason is null,
    'reason', v_reason,
    'resets_at', v_resets_at,
    'daily_used', v_daily,
    'daily_limit', v_limits.daily_limit,
    'monthly_used', v_monthly,
    'monthly_limit', v_limits.monthly_limit
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Save a result the app produced
-- ---------------------------------------------------------------------------

-- SECURITY DEFINER for the same reason as ai_import_finish (#79): users have no
-- write access to the job tables. It only ever creates the caller's own
-- finished job.
--
-- Re-running an import as the other type passes the same import_id, and, like
-- ai_import_start, replaces that import's current run if it's still open
-- (ready or failed). The imports switch (ai_import_limits.enabled) doesn't
-- apply: it governs the project's own spend.
--
-- Nothing caps how often this runs, so a modified client could pile up
-- results. Unreviewed results are capped instead (ai_import_sweep discards
-- them after 7 days), which bounds what one user can store.
create or replace function public.ai_import_save_result(
  p_import_id uuid,
  p_detected_type text,
  p_result jsonb,
  p_provider text,
  p_requested_type text default null,
  p_model text default null,
  p_input_tokens integer default null,
  p_output_tokens integer default null
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_max_ready constant integer := 20;
  v_previous public.ai_import_jobs%rowtype;
  v_job_id uuid;
begin
  if v_user_id is null then
    raise exception 'not_authenticated: sign in required' using errcode = 'P0001';
  end if;
  if p_import_id is null then
    raise exception 'invalid_input: an import id is required' using errcode = 'P0001';
  end if;
  -- Hosted runs are started and finished by the ai function, which is the only
  -- place their caps are enforced.
  if coalesce(p_provider, '') not in ('anthropic', 'openai', 'gemini', 'on_device') then
    raise exception 'invalid_input: not a provider the app can save for' using errcode = 'P0001';
  end if;
  if coalesce(p_detected_type, '') not in ('workout', 'program') then
    raise exception 'invalid_input: a result needs a detected type' using errcode = 'P0001';
  end if;
  if p_requested_type is not null and p_requested_type not in ('workout', 'program') then
    raise exception 'invalid_input: unknown import type' using errcode = 'P0001';
  end if;
  if jsonb_typeof(p_result) is distinct from 'object' then
    raise exception 'invalid_input: the result must be an object' using errcode = 'P0001';
  end if;
  -- Same ceiling as ai_import_finish.
  if pg_catalog.octet_length(p_result::text) > 1048576 then
    raise exception 'result_too_large: the result exceeds 1 MiB' using errcode = 'P0001';
  end if;

  -- The same per-user lock as ai_import_start, so a save and a hosted start
  -- for one import can't both take it.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('ai_import:' || v_user_id::text, 0)
  );

  select * into v_previous
  from public.ai_import_jobs j
  where j.user_id = v_user_id
    and j.import_id = p_import_id
    and j.status <> 'replaced'
  for update;

  if found then
    if v_previous.status not in ('ready', 'failed') then
      raise exception 'import_closed: import % can no longer be run', p_import_id
        using errcode = 'P0001';
    end if;
    update public.ai_import_jobs set status = 'replaced' where id = v_previous.id;
    delete from public.ai_import_results where job_id = v_previous.id;
  end if;

  if (select count(*) from public.ai_import_jobs j
      where j.user_id = v_user_id and j.status = 'ready') >= v_max_ready then
    raise exception 'too_many_pending: review or discard an import first'
      using errcode = 'P0001';
  end if;

  insert into public.ai_import_jobs (
    user_id, import_id, status, provider, requested_type, detected_type,
    counts_toward_limits, finished_at, input_tokens, output_tokens, model
  ) values (
    v_user_id, p_import_id, 'ready', p_provider, p_requested_type, p_detected_type,
    false, now(), p_input_tokens, p_output_tokens, p_model
  )
  returning id into v_job_id;

  insert into public.ai_import_results (job_id, user_id, payload)
  values (v_job_id, v_user_id, p_result);

  return v_job_id;
end;
$$;

-- Default privileges grant every routine to anon.
revoke all on function public.ai_import_save_result(uuid, text, jsonb, text, text, text, integer, integer)
  from public, anon;
grant execute on function public.ai_import_save_result(uuid, text, jsonb, text, text, text, integer, integer)
  to authenticated;
