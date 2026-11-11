-- A row can only hang off a parent with the same owner (#34).
--
-- Every child INSERT/UPDATE policy checks only `auth.uid() = user_id`, so a
-- user could stamp a row with their own id and attach it to someone else's
-- workout or program: on a public workout every viewer saw it, the owner
-- couldn't delete it (DELETE needs their user_id), and copy_workout copied it
-- on. rls_ownership.test.sql found it; its TODO tests are now ordinary tests.
--
-- Why a trigger and not the policies: a policy's WITH CHECK runs as each row
-- is written and can't see rows written earlier in the same statement.
-- copy_program and start_program insert weeks, days, exercises and sets in
-- one statement (data-modifying CTEs), so an EXISTS-on-parent policy rejects
-- their own children. An AFTER ROW trigger runs at the end of the statement,
-- like a foreign key check, and sees them. Checking child.user_id against
-- parent.user_id (rather than auth.uid()) also makes it an invariant of the
-- data, whoever writes it; RLS already pins user_id to the caller.
--
-- Not a composite foreign key: replacing e.g. workout_exercises.workout_id's
-- FK with (workout_id, user_id) would change the relationship PostgREST embeds
-- through, and migrations land before the app (see CLAUDE.md, PGRST201).
--
-- Same shape, same check: a workout's program_instance_id / program_day_id and
-- a program run's program_id must have the workout's/run's owner. Every
-- legitimate writer (start_program, copy_program, the AI import) only points
-- them at the caller's own rows, and no client path copies them.
--
-- Left alone on purpose:
--   copied_from_workout_id / copied_from_program_id point at another user's
--     row by design: that's what a copy is.
--   exercise_id / basis_exercise_id may name another user's custom exercise
--     that's visible through public content; it changes nothing of theirs.
--
-- Safe for the app in production: it never writes a cross-owner row. Rows
-- already written that way stay (triggers don't re-check existing rows), but
-- any further edit to one is refused; the PR has a query to find them.

-- check_parent_owner(parent_table, fk_column): the row's fk_column, when not
-- null, must name a parent_table row whose user_id equals the row's user_id.
--
-- SECURITY INVOKER: the parent lookup runs under the writer's RLS. Their own
-- parent is always visible to them; another user's private parent reads as
-- missing and is refused the same way as a mismatched owner.
create function public.check_parent_owner()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_parent_id uuid := (to_jsonb(new) ->> tg_argv[1])::uuid;
  v_parent_owner uuid;
begin
  if v_parent_id is null then
    return null;
  end if;

  execute format('select user_id from public.%I where id = $1', tg_argv[0])
    into v_parent_owner
    using v_parent_id;

  if v_parent_owner is distinct from new.user_id then
    raise exception 'parent_not_owned: %.% must belong to the same user as the %',
      tg_argv[0], tg_argv[1], tg_table_name
      using errcode = '42501';
  end if;
  return null;
end;
$$;

revoke execute on function public.check_parent_owner() from public, anon, authenticated;

-- One trigger per parent link. `UPDATE OF` limits the re-check to writes that
-- could move a row; editing a set's reps doesn't look up its parent again.
create trigger check_workout_owner
  after insert or update of workout_id, user_id on public.workout_exercises
  for each row execute function public.check_parent_owner('workouts', 'workout_id');

create trigger check_workout_exercise_owner
  after insert or update of workout_exercise_id, user_id on public.workout_sets
  for each row execute function public.check_parent_owner('workout_exercises', 'workout_exercise_id');

create trigger check_program_instance_owner
  after insert or update of program_instance_id, user_id on public.workouts
  for each row execute function public.check_parent_owner('program_instances', 'program_instance_id');

create trigger check_program_day_owner
  after insert or update of program_day_id, user_id on public.workouts
  for each row execute function public.check_parent_owner('program_days', 'program_day_id');

create trigger check_program_owner
  after insert or update of program_id, user_id on public.program_weeks
  for each row execute function public.check_parent_owner('programs', 'program_id');

-- A day has two parents (its program and its week); both must match.
create trigger check_program_owner
  after insert or update of program_id, user_id on public.program_days
  for each row execute function public.check_parent_owner('programs', 'program_id');

create trigger check_program_week_owner
  after insert or update of program_week_id, user_id on public.program_days
  for each row execute function public.check_parent_owner('program_weeks', 'program_week_id');

create trigger check_program_day_owner
  after insert or update of program_day_id, user_id on public.program_exercises
  for each row execute function public.check_parent_owner('program_days', 'program_day_id');

create trigger check_program_exercise_owner
  after insert or update of program_exercise_id, user_id on public.program_sets
  for each row execute function public.check_parent_owner('program_exercises', 'program_exercise_id');

-- A run is only ever of your own program; someone else's public program is
-- copied first (copy_program), and the copy is what runs.
create trigger check_program_owner
  after insert or update of program_id, user_id on public.program_instances
  for each row execute function public.check_parent_owner('programs', 'program_id');
