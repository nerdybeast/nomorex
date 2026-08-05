-- Lets a percentage set resolve against a *different* lift's 1RM than the
-- one being performed (e.g. Front Squat sets at "% of Clean & Jerk").
-- Null preserves today's exact behavior: percentage of the set's own
-- exercise's 1RM.
ALTER TABLE public.workout_sets
  ADD COLUMN basis_exercise_id uuid REFERENCES public.exercises(id) ON DELETE SET NULL;

-- basis_exercise_id is more likely to go stale than workout_exercises.exercise_id
-- (it's not "the" exercise of the row it's on), so it gets an explicit
-- ON DELETE SET NULL even though the existing exercise_id FK doesn't use one.

-- Sibling to "Read exercises used in public workouts"
-- (20260802213619_add_workout_visibility.sql): without this, a public
-- workout's viewer sees null for a basis exercise's name if it's a custom
-- exercise owned by someone else.
CREATE POLICY "Read exercises used as a public workout's set basis" ON public.exercises
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.workout_sets ws
    JOIN public.workout_exercises we ON we.id = ws.workout_exercise_id
    JOIN public.workouts w ON w.id = we.workout_id
    WHERE ws.basis_exercise_id = exercises.id AND w.is_public = true
  ));
