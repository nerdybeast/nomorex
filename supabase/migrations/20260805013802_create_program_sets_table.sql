-- Structurally identical to workout_sets minus the logging-only columns
-- (completed, actual_weight_kg, actual_reps), plus basis_exercise_id from
-- day one (see 20260805013014_add_basis_exercise_to_workout_sets.sql for
-- the equivalent addition to workout_sets).
create table public.program_sets (
  id                    uuid primary key default gen_random_uuid(),
  program_exercise_id   uuid not null references public.program_exercises(id) on delete cascade,
  user_id               uuid not null references auth.users(id) on delete cascade,
  position              integer not null,
  target_reps           integer,
  weight_mode           text not null check (weight_mode in ('percentage','absolute')),
  percentage            numeric,
  absolute_weight_kg    numeric,
  basis_exercise_id     uuid references public.exercises(id) on delete set null,
  note                  text,
  created_at            timestamptz not null default now(),
  constraint program_sets_weight_mode_value check (
    (weight_mode = 'percentage' and percentage is not null)
    or (weight_mode = 'absolute' and absolute_weight_kg is not null)
  )
);

alter table public.program_sets enable row level security;
create index idx_program_sets_program_exercise_id on public.program_sets (program_exercise_id);

create policy program_sets_select on public.program_sets
  for select to authenticated using ((select auth.uid()) = user_id);
create policy program_sets_insert on public.program_sets
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy program_sets_update on public.program_sets
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy program_sets_delete on public.program_sets
  for delete to authenticated using ((select auth.uid()) = user_id);

create policy program_sets_select_public on public.program_sets
  for select to authenticated using (exists (
    select 1 from public.program_exercises pe
    join public.program_days pd on pd.id = pe.program_day_id
    join public.programs p on p.id = pd.program_id
    where pe.id = program_sets.program_exercise_id and p.is_public = true
  ));

-- Exercise-visibility extensions (same pattern as the workout equivalents in
-- 20260802213619_add_workout_visibility.sql and
-- 20260805013014_add_basis_exercise_to_workout_sets.sql): a viewer of a
-- public program otherwise has no read access to another user's custom
-- exercises used within it, so the joined name would come back null.
CREATE POLICY "Read exercises used in public programs" ON public.exercises
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.program_exercises pe
    JOIN public.program_days pd ON pd.id = pe.program_day_id
    JOIN public.programs p ON p.id = pd.program_id
    WHERE pe.exercise_id = exercises.id AND p.is_public = true
  ));

CREATE POLICY "Read exercises used as a public program's set basis" ON public.exercises
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.program_sets ps
    JOIN public.program_exercises pe ON pe.id = ps.program_exercise_id
    JOIN public.program_days pd ON pd.id = pe.program_day_id
    JOIN public.programs p ON p.id = pd.program_id
    WHERE ps.basis_exercise_id = exercises.id AND p.is_public = true
  ));
