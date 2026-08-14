-- Ties repeat completions of the same logical workout together so history
-- can be queried and only one instance can be in progress at a time.
-- Every existing/new row gets its own fresh id via the default; "doing a
-- workout again" is the only path that carries an existing id forward
-- instead of taking the default (see repeatWorkout()).
alter table public.workouts
  add column workout_group_id uuid not null default gen_random_uuid();

create index idx_workouts_group_id on public.workouts (workout_group_id);

-- Only one in-progress/paused session per logical workout at a time. Backs
-- the client's proactive check in repeatWorkout() and is also the
-- authoritative guard against a race between two concurrent starts.
create unique index idx_workouts_one_active_per_group
  on public.workouts (user_id, workout_group_id)
  where status in ('in_progress', 'paused');
