-- workouts: one dated training session owned by a user
create table public.workouts (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  title      text not null,
  date       date not null,
  notes      text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.workout_exercises (
  id          uuid primary key default gen_random_uuid(),
  workout_id  uuid not null references public.workouts (id) on delete cascade,
  user_id     uuid not null references auth.users (id) on delete cascade,
  exercise_id uuid not null references public.exercises (id),
  position    int  not null,
  notes       text,
  created_at  timestamptz not null default now()
);

create table public.workout_sets (
  id                  uuid primary key default gen_random_uuid(),
  workout_exercise_id uuid not null references public.workout_exercises (id) on delete cascade,
  user_id             uuid not null references auth.users (id) on delete cascade,
  position            int  not null,
  target_reps         int,
  weight_mode         text not null check (weight_mode in ('percentage', 'absolute')),
  percentage          numeric,
  absolute_weight_kg  numeric,
  note                text,
  completed           boolean not null default false,
  actual_weight_kg    numeric,
  actual_reps         int,
  created_at          timestamptz not null default now(),
  constraint weight_mode_value check (
        (weight_mode = 'percentage' and percentage is not null)
     or (weight_mode = 'absolute'   and absolute_weight_kg is not null)
  )
);

create index workouts_user_date_idx       on public.workouts (user_id, date desc);
create index workout_exercises_workout_idx on public.workout_exercises (workout_id);
create index workout_sets_exercise_idx     on public.workout_sets (workout_exercise_id);

-- RLS: every table owner-scoped via user_id
alter table public.workouts          enable row level security;
alter table public.workout_exercises enable row level security;
alter table public.workout_sets      enable row level security;

create policy "workouts_select" on public.workouts for select
  to authenticated using ((select auth.uid()) = user_id);
create policy "workouts_insert" on public.workouts for insert
  to authenticated with check ((select auth.uid()) = user_id);
create policy "workouts_update" on public.workouts for update
  to authenticated using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "workouts_delete" on public.workouts for delete
  to authenticated using ((select auth.uid()) = user_id);

create policy "workout_exercises_select" on public.workout_exercises for select
  to authenticated using ((select auth.uid()) = user_id);
create policy "workout_exercises_insert" on public.workout_exercises for insert
  to authenticated with check ((select auth.uid()) = user_id);
create policy "workout_exercises_update" on public.workout_exercises for update
  to authenticated using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "workout_exercises_delete" on public.workout_exercises for delete
  to authenticated using ((select auth.uid()) = user_id);

create policy "workout_sets_select" on public.workout_sets for select
  to authenticated using ((select auth.uid()) = user_id);
create policy "workout_sets_insert" on public.workout_sets for insert
  to authenticated with check ((select auth.uid()) = user_id);
create policy "workout_sets_update" on public.workout_sets for update
  to authenticated using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "workout_sets_delete" on public.workout_sets for delete
  to authenticated using ((select auth.uid()) = user_id);
