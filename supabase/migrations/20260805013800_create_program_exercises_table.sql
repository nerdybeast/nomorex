-- Structurally identical to workout_exercises, minus nothing.
create table public.program_exercises (
  id              uuid primary key default gen_random_uuid(),
  program_day_id  uuid not null references public.program_days(id) on delete cascade,
  user_id         uuid not null references auth.users(id) on delete cascade,
  exercise_id     uuid not null references public.exercises(id),
  position        integer not null,
  notes           text,
  created_at      timestamptz not null default now()
);

alter table public.program_exercises enable row level security;
create index idx_program_exercises_program_day_id on public.program_exercises (program_day_id);

create policy program_exercises_select on public.program_exercises
  for select to authenticated using ((select auth.uid()) = user_id);
create policy program_exercises_insert on public.program_exercises
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy program_exercises_update on public.program_exercises
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy program_exercises_delete on public.program_exercises
  for delete to authenticated using ((select auth.uid()) = user_id);

-- Mirrors workout_exercises_select_public: program_exercises carries the
-- OWNER's user_id, which can't gate a viewer's read, so this needs an EXISTS
-- back through program_days -> programs.is_public.
create policy program_exercises_select_public on public.program_exercises
  for select to authenticated using (exists (
    select 1 from public.program_days pd
    join public.programs p on p.id = pd.program_id
    where pd.id = program_exercises.program_day_id and p.is_public = true
  ));
