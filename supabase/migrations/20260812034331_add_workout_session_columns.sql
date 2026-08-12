-- Session-tracking columns for the workout start/pause/resume/finish flow.
-- Status is an explicit column (not derived from the timestamps) to match
-- the program_instances.status precedent and keep the dashboard's "in
-- progress" query a simple equality/IN filter.
alter table public.workouts
  add column status text not null default 'not_started'
    check (status in ('not_started', 'in_progress', 'paused', 'finished')),
  add column started_at timestamptz,
  add column paused_at timestamptz,
  add column total_paused_seconds integer not null default 0
    check (total_paused_seconds >= 0),
  add column finished_at timestamptz,
  add column session_notes text;

-- Supports the dashboard's "workouts in progress" query
-- (workouts where user_id = ? and status in ('in_progress','paused')).
create index idx_workouts_in_progress on public.workouts (user_id, status)
  where status in ('in_progress', 'paused');
