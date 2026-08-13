-- Fix advisor finding: multiple_permissive_policies
-- Each pair of {owner-only, public} SELECT policies below is ORed together by Postgres
-- already (each migration that introduced a "_public" policy said as much in its own
-- comments) -- this merges them into a single policy per table so the planner only has
-- to evaluate one permissive policy per query instead of two-plus.

-- public.programs
drop policy if exists programs_select on public.programs;
drop policy if exists programs_select_public on public.programs;
create policy programs_select on public.programs
  for select to authenticated
  using ((select auth.uid()) = user_id or is_public = true);

-- public.program_weeks
drop policy if exists program_weeks_select on public.program_weeks;
drop policy if exists program_weeks_select_public on public.program_weeks;
create policy program_weeks_select on public.program_weeks
  for select to authenticated
  using (
    (select auth.uid()) = user_id
    or exists (
      select 1 from public.programs p
      where p.id = program_weeks.program_id and p.is_public = true
    )
  );

-- public.program_days
drop policy if exists program_days_select on public.program_days;
drop policy if exists program_days_select_public on public.program_days;
create policy program_days_select on public.program_days
  for select to authenticated
  using (
    (select auth.uid()) = user_id
    or exists (
      select 1 from public.programs p
      where p.id = program_days.program_id and p.is_public = true
    )
  );

-- public.program_exercises
drop policy if exists program_exercises_select on public.program_exercises;
drop policy if exists program_exercises_select_public on public.program_exercises;
create policy program_exercises_select on public.program_exercises
  for select to authenticated
  using (
    (select auth.uid()) = user_id
    or exists (
      select 1 from public.program_days pd
      join public.programs p on p.id = pd.program_id
      where pd.id = program_exercises.program_day_id and p.is_public = true
    )
  );

-- public.program_sets
drop policy if exists program_sets_select on public.program_sets;
drop policy if exists program_sets_select_public on public.program_sets;
create policy program_sets_select on public.program_sets
  for select to authenticated
  using (
    (select auth.uid()) = user_id
    or exists (
      select 1 from public.program_exercises pe
      join public.program_days pd on pd.id = pe.program_day_id
      join public.programs p on p.id = pd.program_id
      where pe.id = program_sets.program_exercise_id and p.is_public = true
    )
  );

-- public.workouts
drop policy if exists workouts_select on public.workouts;
drop policy if exists workouts_select_public on public.workouts;
create policy workouts_select on public.workouts
  for select to authenticated
  using ((select auth.uid()) = user_id or is_public = true);

-- public.workout_exercises
drop policy if exists workout_exercises_select on public.workout_exercises;
drop policy if exists workout_exercises_select_public on public.workout_exercises;
create policy workout_exercises_select on public.workout_exercises
  for select to authenticated
  using (
    (select auth.uid()) = user_id
    or exists (
      select 1 from public.workouts w
      where w.id = workout_exercises.workout_id and w.is_public = true
    )
  );

-- public.workout_sets
drop policy if exists workout_sets_select on public.workout_sets;
drop policy if exists workout_sets_select_public on public.workout_sets;
create policy workout_sets_select on public.workout_sets
  for select to authenticated
  using (
    (select auth.uid()) = user_id
    or exists (
      select 1 from public.workout_exercises we
      join public.workouts w on w.id = we.workout_id
      where we.id = workout_sets.workout_exercise_id and w.is_public = true
    )
  );

-- public.exercises
-- Six previously-separate SELECT policies (own custom / predefined / referenced by a
-- public workout / referenced as a public workout's basis / referenced by a public
-- program / referenced as a public program's basis) merged into one OR'd policy.
drop policy if exists "Read own custom exercises" on public.exercises;
drop policy if exists "Read predefined exercises" on public.exercises;
drop policy if exists "Read exercises used in public workouts" on public.exercises;
drop policy if exists "Read exercises used as a public workout's set basis" on public.exercises;
drop policy if exists "Read exercises used in public programs" on public.exercises;
drop policy if exists "Read exercises used as a public program's set basis" on public.exercises;
create policy "Read exercises" on public.exercises
  for select to authenticated
  using (
    (is_predefined = false and user_id = (select auth.uid()))
    or is_predefined = true
    or exists (
      select 1 from public.workout_exercises we
      join public.workouts w on w.id = we.workout_id
      where we.exercise_id = exercises.id and w.is_public = true
    )
    or exists (
      select 1 from public.workout_sets ws
      join public.workout_exercises we on we.id = ws.workout_exercise_id
      join public.workouts w on w.id = we.workout_id
      where ws.basis_exercise_id = exercises.id and w.is_public = true
    )
    or exists (
      select 1 from public.program_exercises pe
      join public.program_days pd on pd.id = pe.program_day_id
      join public.programs p on p.id = pd.program_id
      where pe.exercise_id = exercises.id and p.is_public = true
    )
    or exists (
      select 1 from public.program_sets ps
      join public.program_exercises pe on pe.id = ps.program_exercise_id
      join public.program_days pd on pd.id = pe.program_day_id
      join public.programs p on p.id = pd.program_id
      where ps.basis_exercise_id = exercises.id and p.is_public = true
    )
  );
