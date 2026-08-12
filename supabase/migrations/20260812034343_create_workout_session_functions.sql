-- Workout session transitions (start/pause/resume/finish/discard). Each is
-- security invoker (RLS-gated exactly like a direct client update, matching
-- the start_program precedent) and computes now() server-side rather than
-- trusting a client-supplied timestamp, avoiding device-clock-skew bugs and
-- read-modify-write races on total_paused_seconds. Each update is guarded by
-- a status precondition so a stale/duplicate call safely no-ops instead of
-- corrupting state.

create or replace function public.start_workout_session(p_workout_id uuid)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  update public.workouts
  set status = 'in_progress', started_at = now()
  where id = p_workout_id
    and user_id = (select auth.uid())
    and status = 'not_started';
end;
$$;

create or replace function public.pause_workout_session(p_workout_id uuid)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  update public.workouts
  set status = 'paused', paused_at = now()
  where id = p_workout_id
    and user_id = (select auth.uid())
    and status = 'in_progress';
end;
$$;

create or replace function public.resume_workout_session(p_workout_id uuid)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  update public.workouts
  set status = 'in_progress',
      total_paused_seconds = total_paused_seconds + extract(epoch from (now() - paused_at))::int,
      paused_at = null
  where id = p_workout_id
    and user_id = (select auth.uid())
    and status = 'paused';
end;
$$;

-- finished_at is set to paused_at when already paused (the freeze instant
-- from an implicit or explicit pause), so time spent on the Finish screen
-- writing notes is never counted as workout duration. Falls back to now()
-- as a defensive case if somehow still in_progress when this is called.
create or replace function public.finish_workout_session(p_workout_id uuid, p_session_notes text)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  update public.workouts
  set status = 'finished',
      finished_at = case when status = 'paused' then paused_at else now() end,
      paused_at = null,
      session_notes = p_session_notes
  where id = p_workout_id
    and user_id = (select auth.uid())
    and status in ('in_progress', 'paused');
end;
$$;

create or replace function public.discard_workout_session(p_workout_id uuid)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  update public.workouts
  set status = 'not_started',
      started_at = null,
      paused_at = null,
      total_paused_seconds = 0,
      finished_at = null,
      session_notes = null
  where id = p_workout_id
    and user_id = (select auth.uid());
end;
$$;
