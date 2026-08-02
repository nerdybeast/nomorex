ALTER TABLE public.workouts
  ADD COLUMN is_public boolean NOT NULL DEFAULT false;

CREATE INDEX workouts_public_date_idx ON public.workouts (date DESC)
  WHERE is_public = true;

-- Postgres ORs multiple permissive policies for the same role+command,
-- so this only widens the existing owner-only workouts_select policy.
CREATE POLICY workouts_select_public ON public.workouts
  FOR SELECT TO authenticated
  USING (is_public = true);

-- workout_exercises/workout_sets carry the OWNER's user_id, which can't
-- gate a viewer's read, so these need an EXISTS back to workouts.is_public.
CREATE POLICY workout_exercises_select_public ON public.workout_exercises
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.workouts w
    WHERE w.id = workout_exercises.workout_id AND w.is_public = true
  ));

CREATE POLICY workout_sets_select_public ON public.workout_sets
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.workout_exercises we
    JOIN public.workouts w ON w.id = we.workout_id
    WHERE we.id = workout_sets.workout_exercise_id AND w.is_public = true
  ));

-- If a public workout uses another user's custom (non-predefined) exercise,
-- the viewer has no existing SELECT access to that exercises row, so the
-- joined name would come back null. Grant read access to exercises used in
-- public workouts.
CREATE POLICY "Read exercises used in public workouts" ON public.exercises
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.workout_exercises we
    JOIN public.workouts w ON w.id = we.workout_id
    WHERE we.exercise_id = exercises.id AND w.is_public = true
  ));
