-- Foundation for AI import of workouts and programs (#81, part of #79).
-- Additive, and nothing calls it yet. Imports start switched off
-- (ai_import_limits.enabled): the functions and bucket are reachable from the
-- moment this deploys, and there is no app feature to justify opening them.
--
-- One ai_import_jobs row is one AI run. Re-running an import as the other type
-- adds a run and marks the previous one 'replaced', so every run stays
-- countable. import_id groups the runs and names the Storage folder.

-- ---------------------------------------------------------------------------
-- Imported marker
-- ---------------------------------------------------------------------------

-- Only chooses the badge wording. Privacy comes from is_copy.
alter table public.workouts
  add column is_imported boolean not null default false;
alter table public.programs
  add column is_imported boolean not null default false;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

-- Everything references auth.users rather than profiles: a second FK to
-- profiles can make PostgREST embeds ambiguous, and the cascade removes a
-- user's imports with their account.

-- Published to Realtime, so this stays small. The result is in its own table.
create table public.ai_import_jobs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  import_id uuid not null,
  status text not null default 'processing'
    check (status in ('processing', 'ready', 'failed', 'accepted', 'discarded', 'replaced')),
  requested_type text check (requested_type in ('workout', 'program')),
  detected_type text check (detected_type in ('workout', 'program')),
  failure_code text check (failure_code in (
    'no_workout_found', 'invalid_file', 'unreadable_file', 'timeout',
    'model_error', 'invalid_output', 'internal_error', 'abandoned'
  )),
  -- True from the start so a running job holds its place under the caps.
  counts_toward_limits boolean not null default true,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  input_tokens integer check (input_tokens >= 0),
  output_tokens integer check (output_tokens >= 0),
  model text check (char_length(model) <= 100),
  accepted_workout_id uuid references public.workouts (id) on delete set null,
  accepted_program_id uuid references public.programs (id) on delete set null,
  constraint ai_import_jobs_failed_has_code
    check (status <> 'failed' or failure_code is not null),
  constraint ai_import_jobs_one_accepted_item
    check (num_nonnulls(accepted_workout_id, accepted_program_id) <= 1)
);

alter table public.ai_import_jobs enable row level security;

-- What makes "one active job per user" true however starts interleave.
create unique index ai_import_jobs_one_active_per_user
  on public.ai_import_jobs (user_id) where status = 'processing';
-- An import has one current run. Scoped by user so a guessed import_id can't
-- collide with, or reveal, another user's.
create unique index ai_import_jobs_one_current_run
  on public.ai_import_jobs (user_id, import_id) where status <> 'replaced';
create index idx_ai_import_jobs_user_started
  on public.ai_import_jobs (user_id, started_at desc);

create table public.ai_import_results (
  job_id uuid primary key references public.ai_import_jobs (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  payload jsonb not null,
  created_at timestamptz not null default now()
);

alter table public.ai_import_results enable row level security;

create index idx_ai_import_results_user on public.ai_import_results (user_id);

-- One row, applying to everyone. Change it with SQL; no app release needed.
-- The file caps are provisional, from the #80 spike. Raising max_pdf_bytes
-- past 20 MB also means raising the bucket's file_size_limit below.
create table public.ai_import_limits (
  id boolean primary key default true check (id),
  enabled boolean not null default false,
  daily_limit integer not null default 5 check (daily_limit >= 0),
  monthly_limit integer not null default 30 check (monthly_limit >= 0),
  uncounted_failure_daily_limit integer not null default 10
    check (uncounted_failure_daily_limit >= 0),
  max_images integer not null default 8 check (max_images > 0),
  max_pdf_pages integer not null default 10 check (max_pdf_pages > 0),
  max_image_bytes bigint not null default 7000000 check (max_image_bytes > 0),
  max_pdf_bytes bigint not null default 20000000 check (max_pdf_bytes > 0),
  -- Longer than a job can possibly run (150s wall clock on the Free plan).
  -- Raise it above 400 if the project moves to a paid plan.
  max_job_seconds integer not null default 180 check (max_job_seconds > 0)
);

alter table public.ai_import_limits enable row level security;

insert into public.ai_import_limits (id) values (true);

-- Not on profiles, whose rows other users can sometimes read.
create table public.ai_import_consents (
  user_id uuid primary key references auth.users (id) on delete cascade,
  accepted_at timestamptz not null default now()
);

alter table public.ai_import_consents enable row level security;

-- ---------------------------------------------------------------------------
-- Access
-- ---------------------------------------------------------------------------

-- The project's default privileges grant everything to anon and authenticated,
-- so RLS alone would be the only barrier. Take the grants away as well.
revoke all on public.ai_import_jobs, public.ai_import_results,
  public.ai_import_limits, public.ai_import_consents
  from anon, authenticated;

grant select on public.ai_import_jobs, public.ai_import_results,
  public.ai_import_limits, public.ai_import_consents
  to authenticated;
-- Column-level, so accepted_at can only ever be the server's clock.
grant insert (user_id) on public.ai_import_consents to authenticated;

create policy ai_import_jobs_select on public.ai_import_jobs
  for select to authenticated
  using ((select auth.uid()) = user_id);

create policy ai_import_results_select on public.ai_import_results
  for select to authenticated
  using ((select auth.uid()) = user_id);

-- Global settings, not user data: the app needs the file caps before upload.
create policy ai_import_limits_select on public.ai_import_limits
  for select to authenticated
  using (true);

create policy ai_import_consents_select on public.ai_import_consents
  for select to authenticated
  using ((select auth.uid()) = user_id);

create policy ai_import_consents_insert on public.ai_import_consents
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

-- Realtime only nudges the app to re-read this row. Results are never published.
alter publication supabase_realtime add table public.ai_import_jobs;

-- ---------------------------------------------------------------------------
-- Pre-upload check
-- ---------------------------------------------------------------------------

-- SECURITY INVOKER: it only reads the caller's own rows and the limits.
-- A processing job past max_job_seconds is treated as dead here, without being
-- written, so it can never block anyone.
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
-- Job transitions
-- ---------------------------------------------------------------------------

-- These are SECURITY DEFINER, as justified on #79: under SECURITY INVOKER the
-- caller would need write policies on the rows that enforce their own quota.
-- Each one performs a single transition on the caller's own job, and all of
-- them use an empty search_path so nothing can be substituted for the objects
-- they name.

create or replace function public.ai_import_start(
  p_import_id uuid,
  p_requested_type text default null
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_check jsonb;
  v_previous public.ai_import_jobs%rowtype;
  v_job_id uuid;
begin
  if v_user_id is null then
    raise exception 'not_authenticated: sign in required' using errcode = 'P0001';
  end if;
  if p_import_id is null then
    raise exception 'invalid_input: an import id is required' using errcode = 'P0001';
  end if;
  if p_requested_type is not null and p_requested_type not in ('workout', 'program') then
    raise exception 'invalid_input: unknown import type' using errcode = 'P0001';
  end if;

  -- Serializes one user's starts, so the caps below are counted and consumed
  -- as a single step.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('ai_import:' || v_user_id::text, 0)
  );

  update public.ai_import_jobs j
  set status = 'failed',
      failure_code = 'abandoned',
      counts_toward_limits = false,
      finished_at = now()
  from public.ai_import_limits l
  where j.user_id = v_user_id
    and j.status = 'processing'
    and j.started_at < now() - make_interval(secs => l.max_job_seconds);

  v_check := public.ai_import_check();
  if not (v_check ->> 'allowed')::boolean then
    raise exception '%: this import cannot start', v_check ->> 'reason'
      using errcode = 'P0001';
  end if;

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

  insert into public.ai_import_jobs (user_id, import_id, requested_type)
  values (v_user_id, p_import_id, p_requested_type)
  returning id into v_job_id;

  return v_job_id;
end;
$$;

-- Exactly one of p_result (the job succeeded) or p_failure_code (it didn't).
-- Whether a failure counts is decided here from the code, never by the caller.
-- Works while imports are switched off, so a running import can still finish.
create or replace function public.ai_import_finish(
  p_job_id uuid,
  p_detected_type text default null,
  p_result jsonb default null,
  p_failure_code text default null,
  p_input_tokens integer default null,
  p_output_tokens integer default null,
  p_model text default null
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_job public.ai_import_jobs%rowtype;
begin
  if v_user_id is null then
    raise exception 'not_authenticated: sign in required' using errcode = 'P0001';
  end if;
  if (p_result is null) = (p_failure_code is null) then
    raise exception 'invalid_input: give either a result or a failure code'
      using errcode = 'P0001';
  end if;
  if p_result is not null and coalesce(p_detected_type, '') not in ('workout', 'program') then
    raise exception 'invalid_input: a result needs a detected type' using errcode = 'P0001';
  end if;
  -- 'abandoned' is only ever assigned by the database.
  if p_failure_code = 'abandoned' then
    raise exception 'invalid_input: unknown failure code' using errcode = 'P0001';
  end if;
  -- Far above real output (about 100 KB at the 20,000 token cap). Callers run
  -- as the user, so this stops a modified client storing arbitrary amounts.
  if pg_catalog.octet_length(p_result::text) > 1048576 then
    raise exception 'result_too_large: the result exceeds 1 MiB' using errcode = 'P0001';
  end if;

  select * into v_job
  from public.ai_import_jobs j
  where j.id = p_job_id and j.user_id = v_user_id
  for update;
  if not found then
    raise exception 'not_found: import job % is not available', p_job_id
      using errcode = 'P0001';
  end if;
  if v_job.status <> 'processing' then
    raise exception 'not_processing: import job % already finished', p_job_id
      using errcode = 'P0001';
  end if;

  update public.ai_import_jobs
  set status = case when p_result is null then 'failed' else 'ready' end,
      detected_type = p_detected_type,
      failure_code = p_failure_code,
      -- A fully processed file with no workout in it still used an import.
      counts_toward_limits = p_result is not null or p_failure_code = 'no_workout_found',
      finished_at = now(),
      input_tokens = p_input_tokens,
      output_tokens = p_output_tokens,
      model = p_model
  where id = p_job_id;

  if p_result is not null then
    insert into public.ai_import_results (job_id, user_id, payload)
    values (p_job_id, v_user_id, p_result);
  end if;
end;
$$;

-- Locks the job until the caller's transaction ends, so a double tap or second
-- device waits here and then sees 'accepted' with the existing item's id.
create or replace function public.ai_import_claim(p_job_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_job public.ai_import_jobs%rowtype;
begin
  if v_user_id is null then
    raise exception 'not_authenticated: sign in required' using errcode = 'P0001';
  end if;

  select * into v_job
  from public.ai_import_jobs j
  where j.id = p_job_id and j.user_id = v_user_id
  for update;
  if not found then
    raise exception 'not_found: import job % is not available', p_job_id
      using errcode = 'P0001';
  end if;
  if v_job.status not in ('ready', 'accepted') then
    raise exception 'not_ready: import job % cannot be accepted', p_job_id
      using errcode = 'P0001';
  end if;

  return jsonb_build_object(
    'status', v_job.status,
    'workout_id', v_job.accepted_workout_id,
    'program_id', v_job.accepted_program_id
  );
end;
$$;

create or replace function public.ai_import_mark_accepted(
  p_job_id uuid,
  p_workout_id uuid default null,
  p_program_id uuid default null
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
begin
  if v_user_id is null then
    raise exception 'not_authenticated: sign in required' using errcode = 'P0001';
  end if;
  if num_nonnulls(p_workout_id, p_program_id) <> 1 then
    raise exception 'invalid_input: give either a workout or a program' using errcode = 'P0001';
  end if;
  -- This function bypasses RLS, so it has to check the item's owner itself.
  if not exists (
    select 1 from public.workouts w where w.id = p_workout_id and w.user_id = v_user_id
  ) and not exists (
    select 1 from public.programs p where p.id = p_program_id and p.user_id = v_user_id
  ) then
    raise exception 'not_found: the accepted item is not available' using errcode = 'P0001';
  end if;

  update public.ai_import_jobs
  set status = 'accepted',
      accepted_workout_id = p_workout_id,
      accepted_program_id = p_program_id
  where id = p_job_id and user_id = v_user_id and status = 'ready';
  if not found then
    raise exception 'not_ready: import job % cannot be accepted', p_job_id
      using errcode = 'P0001';
  end if;

  delete from public.ai_import_results where job_id = p_job_id;
end;
$$;

-- Repeating a discard is harmless, so it succeeds and changes nothing.
create or replace function public.ai_import_discard(p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_job public.ai_import_jobs%rowtype;
begin
  if v_user_id is null then
    raise exception 'not_authenticated: sign in required' using errcode = 'P0001';
  end if;

  select * into v_job
  from public.ai_import_jobs j
  where j.id = p_job_id and j.user_id = v_user_id
  for update;
  if not found then
    raise exception 'not_found: import job % is not available', p_job_id
      using errcode = 'P0001';
  end if;
  if v_job.status = 'discarded' then
    return;
  end if;
  if v_job.status not in ('ready', 'failed') then
    raise exception 'not_discardable: import job % cannot be discarded', p_job_id
      using errcode = 'P0001';
  end if;

  update public.ai_import_jobs set status = 'discarded' where id = p_job_id;
  delete from public.ai_import_results where job_id = p_job_id;
end;
$$;

revoke all on function public.ai_import_check() from public, anon;
revoke all on function public.ai_import_start(uuid, text) from public, anon;
revoke all on function public.ai_import_finish(uuid, text, jsonb, text, integer, integer, text)
  from public, anon;
revoke all on function public.ai_import_claim(uuid) from public, anon;
revoke all on function public.ai_import_mark_accepted(uuid, uuid, uuid) from public, anon;
revoke all on function public.ai_import_discard(uuid) from public, anon;

grant execute on function public.ai_import_check() to authenticated;
grant execute on function public.ai_import_start(uuid, text) to authenticated;
grant execute on function public.ai_import_finish(uuid, text, jsonb, text, integer, integer, text)
  to authenticated;
grant execute on function public.ai_import_claim(uuid) to authenticated;
grant execute on function public.ai_import_mark_accepted(uuid, uuid, uuid) to authenticated;
grant execute on function public.ai_import_discard(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Storage
-- ---------------------------------------------------------------------------

-- The MIME list only sees the type the uploader declares, so it can't catch a
-- disguised file. The real check reads the file's bytes (#82).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'ai-imports', 'ai-imports', false, 20000000,
  array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
);

-- Paths are {user_id}/{import_id}/{file}. There is deliberately no UPDATE
-- policy: a file is never replaced in place.
create policy ai_imports_objects_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'ai-imports'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- Enforces the notice (FR-004), caps and off switch on the upload itself, so a
-- modified client that skips the pre-upload check still can't upload.
create policy ai_imports_objects_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'ai-imports'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and array_length(storage.foldername(name), 1) = 2
    and (storage.foldername(name))[2]
      ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and ((select public.ai_import_check()) ->> 'allowed')::boolean
  );

create policy ai_imports_objects_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'ai-imports'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
