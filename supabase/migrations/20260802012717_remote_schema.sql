-- Migration unit 1: schema_changes
-- Transaction mode: transactional
-- Boundary reason: default

SET check_function_bodies = false;

DROP EXTENSION pg_net;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT DELETE, INSERT, SELECT, UPDATE ON TABLES TO anon;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT, USAGE ON SEQUENCES TO anon;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON ROUTINES TO anon;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT DELETE, INSERT, SELECT, UPDATE ON TABLES TO authenticated;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT, USAGE ON SEQUENCES TO authenticated;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON ROUTINES TO authenticated;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT DELETE, INSERT, SELECT, UPDATE ON TABLES TO service_role;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT, USAGE ON SEQUENCES TO service_role;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON ROUTINES TO service_role;

CREATE FUNCTION public.handle_new_user()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  insert into public.profiles (id) values (new.id);
  return new;
end;
$function$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

GRANT ALL ON FUNCTION public.handle_new_user() TO anon;

GRANT ALL ON FUNCTION public.handle_new_user() TO authenticated;

GRANT ALL ON FUNCTION public.handle_new_user() TO service_role;

CREATE FUNCTION public.set_updated_at()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin new.updated_at = now(); return new; end;
$function$;

GRANT ALL ON FUNCTION public.set_updated_at() TO anon;

GRANT ALL ON FUNCTION public.set_updated_at() TO authenticated;

GRANT ALL ON FUNCTION public.set_updated_at() TO service_role;

CREATE TABLE public.exercises (
  id            uuid                     DEFAULT gen_random_uuid() NOT NULL,
  name          text                     NOT NULL,
  is_predefined boolean                  DEFAULT false NOT NULL,
  user_id       uuid,
  created_at    timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.exercises
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.exercises
  ADD CONSTRAINT exercises_pkey PRIMARY KEY (id);

ALTER TABLE public.exercises
  ADD CONSTRAINT exercises_predefined_check CHECK (is_predefined = true AND user_id IS NULL OR is_predefined = false AND user_id IS NOT NULL);

ALTER TABLE public.exercises
  ADD CONSTRAINT exercises_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

GRANT ALL ON public.exercises TO anon;

GRANT ALL ON public.exercises TO authenticated;

GRANT ALL ON public.exercises TO service_role;

CREATE INDEX idx_exercises_user_id ON public.exercises (user_id);

CREATE POLICY "Delete own custom exercises" ON public.exercises
  FOR DELETE
  TO authenticated
  USING (((is_predefined = false) AND (user_id = auth.uid())));

CREATE POLICY "Insert own custom exercises" ON public.exercises
  FOR INSERT
  TO authenticated
  WITH CHECK (((is_predefined = false) AND (user_id = auth.uid())));

CREATE POLICY "Read own custom exercises" ON public.exercises
  FOR SELECT
  TO authenticated
  USING (((is_predefined = false) AND (user_id = auth.uid())));

CREATE POLICY "Read predefined exercises" ON public.exercises
  FOR SELECT
  TO authenticated
  USING ((is_predefined = true));

CREATE POLICY "Update own custom exercises" ON public.exercises
  FOR UPDATE
  TO authenticated
  USING (((is_predefined = false) AND (user_id = auth.uid())))
  WITH CHECK (((is_predefined = false) AND (user_id = auth.uid())));

CREATE TABLE public.personal_bests (
  id          uuid                     DEFAULT gen_random_uuid() NOT NULL,
  user_id     uuid                     NOT NULL,
  exercise_id uuid                     NOT NULL,
  weight_kg   numeric(8,3)             NOT NULL,
  reps        integer                  DEFAULT 1 NOT NULL,
  date        date                     DEFAULT CURRENT_DATE NOT NULL,
  notes       text,
  created_at  timestamp with time zone DEFAULT now() NOT NULL,
  updated_at  timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.personal_bests
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.personal_bests
  ADD CONSTRAINT personal_bests_exercise_id_fkey FOREIGN KEY (exercise_id) REFERENCES public.exercises(id) ON DELETE RESTRICT;

ALTER TABLE public.personal_bests
  ADD CONSTRAINT personal_bests_pkey PRIMARY KEY (id);

ALTER TABLE public.personal_bests
  ADD CONSTRAINT personal_bests_reps_check CHECK (reps > 0);

ALTER TABLE public.personal_bests
  ADD CONSTRAINT personal_bests_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.personal_bests
  ADD CONSTRAINT personal_bests_weight_kg_check CHECK (weight_kg > 0::numeric);

GRANT ALL ON public.personal_bests TO anon;

GRANT ALL ON public.personal_bests TO authenticated;

GRANT ALL ON public.personal_bests TO service_role;

CREATE INDEX idx_personal_bests_user_id ON public.personal_bests (user_id);

CREATE INDEX idx_personal_bests_updated_at ON public.personal_bests (user_id, updated_at DESC);

CREATE TRIGGER set_personal_bests_updated_at
  BEFORE UPDATE ON public.personal_bests
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY "Delete own PRs" ON public.personal_bests
  FOR DELETE
  TO authenticated
  USING ((user_id = auth.uid()));

CREATE POLICY "Insert own PRs" ON public.personal_bests
  FOR INSERT
  TO authenticated
  WITH CHECK ((user_id = auth.uid()));

CREATE POLICY "Select own PRs" ON public.personal_bests
  FOR SELECT
  TO authenticated
  USING ((user_id = auth.uid()));

CREATE POLICY "Update own PRs" ON public.personal_bests
  FOR UPDATE
  TO authenticated
  USING ((user_id = auth.uid()))
  WITH CHECK ((user_id = auth.uid()));

CREATE TABLE public.profiles (
  id              uuid                     NOT NULL,
  unit_preference text                     DEFAULT 'kg'::text NOT NULL,
  created_at      timestamp with time zone DEFAULT now() NOT NULL,
  updated_at      timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.profiles
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_unit_preference_check CHECK (unit_preference = ANY (ARRAY['kg'::text, 'lbs'::text]));

GRANT ALL ON public.profiles TO anon;

GRANT ALL ON public.profiles TO authenticated;

GRANT ALL ON public.profiles TO service_role;

CREATE POLICY "Users can insert own profile" ON public.profiles
  FOR INSERT
  WITH CHECK ((auth.uid() = id));

CREATE POLICY "Users can update own profile" ON public.profiles
  FOR UPDATE
  USING ((auth.uid() = id))
  WITH CHECK ((auth.uid() = id));

CREATE POLICY "Users can view own profile" ON public.profiles
  FOR SELECT
  USING ((auth.uid() = id));

CREATE TABLE public.workout_exercises (
  id          uuid                     DEFAULT gen_random_uuid() NOT NULL,
  workout_id  uuid                     NOT NULL,
  user_id     uuid                     NOT NULL,
  exercise_id uuid                     NOT NULL,
  "position"  integer                  NOT NULL,
  notes       text,
  created_at  timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.workout_exercises
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.workout_exercises
  ADD CONSTRAINT workout_exercises_exercise_id_fkey FOREIGN KEY (exercise_id) REFERENCES public.exercises(id);

ALTER TABLE public.workout_exercises
  ADD CONSTRAINT workout_exercises_pkey PRIMARY KEY (id);

ALTER TABLE public.workout_exercises
  ADD CONSTRAINT workout_exercises_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

GRANT ALL ON public.workout_exercises TO anon;

GRANT ALL ON public.workout_exercises TO authenticated;

GRANT ALL ON public.workout_exercises TO service_role;

CREATE INDEX workout_exercises_workout_idx ON public.workout_exercises (workout_id);

CREATE POLICY workout_exercises_delete ON public.workout_exercises
  FOR DELETE
  TO authenticated
  USING ((( SELECT auth.uid() AS uid) = user_id));

CREATE POLICY workout_exercises_insert ON public.workout_exercises
  FOR INSERT
  TO authenticated
  WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));

CREATE POLICY workout_exercises_select ON public.workout_exercises
  FOR SELECT
  TO authenticated
  USING ((( SELECT auth.uid() AS uid) = user_id));

CREATE POLICY workout_exercises_update ON public.workout_exercises
  FOR UPDATE
  TO authenticated
  USING ((( SELECT auth.uid() AS uid) = user_id))
  WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));

CREATE TABLE public.workout_sets (
  id                  uuid                     DEFAULT gen_random_uuid() NOT NULL,
  workout_exercise_id uuid                     NOT NULL,
  user_id             uuid                     NOT NULL,
  "position"          integer                  NOT NULL,
  target_reps         integer,
  weight_mode         text                     NOT NULL,
  percentage          numeric,
  absolute_weight_kg  numeric,
  note                text,
  completed           boolean                  DEFAULT false NOT NULL,
  actual_weight_kg    numeric,
  actual_reps         integer,
  created_at          timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.workout_sets
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.workout_sets
  ADD CONSTRAINT weight_mode_value CHECK (weight_mode = 'percentage'::text AND percentage IS NOT NULL OR weight_mode = 'absolute'::text AND absolute_weight_kg IS NOT NULL);

ALTER TABLE public.workout_sets
  ADD CONSTRAINT workout_sets_pkey PRIMARY KEY (id);

ALTER TABLE public.workout_sets
  ADD CONSTRAINT workout_sets_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.workout_sets
  ADD CONSTRAINT workout_sets_weight_mode_check CHECK (weight_mode = ANY (ARRAY['percentage'::text, 'absolute'::text]));

ALTER TABLE public.workout_sets
  ADD CONSTRAINT workout_sets_workout_exercise_id_fkey FOREIGN KEY (workout_exercise_id) REFERENCES public.workout_exercises(id) ON DELETE CASCADE;

GRANT ALL ON public.workout_sets TO anon;

GRANT ALL ON public.workout_sets TO authenticated;

GRANT ALL ON public.workout_sets TO service_role;

CREATE INDEX workout_sets_exercise_idx ON public.workout_sets (workout_exercise_id);

CREATE POLICY workout_sets_delete ON public.workout_sets
  FOR DELETE
  TO authenticated
  USING ((( SELECT auth.uid() AS uid) = user_id));

CREATE POLICY workout_sets_insert ON public.workout_sets
  FOR INSERT
  TO authenticated
  WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));

CREATE POLICY workout_sets_select ON public.workout_sets
  FOR SELECT
  TO authenticated
  USING ((( SELECT auth.uid() AS uid) = user_id));

CREATE POLICY workout_sets_update ON public.workout_sets
  FOR UPDATE
  TO authenticated
  USING ((( SELECT auth.uid() AS uid) = user_id))
  WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));

CREATE TABLE public.workouts (
  id         uuid                     DEFAULT gen_random_uuid() NOT NULL,
  user_id    uuid                     NOT NULL,
  title      text                     NOT NULL,
  date       date                     NOT NULL,
  notes      text,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.workouts
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.workouts
  ADD CONSTRAINT workouts_pkey PRIMARY KEY (id);

ALTER TABLE public.workout_exercises
  ADD CONSTRAINT workout_exercises_workout_id_fkey FOREIGN KEY (workout_id) REFERENCES public.workouts(id) ON DELETE CASCADE;

ALTER TABLE public.workouts
  ADD CONSTRAINT workouts_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

GRANT ALL ON public.workouts TO anon;

GRANT ALL ON public.workouts TO authenticated;

GRANT ALL ON public.workouts TO service_role;

CREATE INDEX workouts_user_date_idx ON public.workouts (user_id, date DESC);

CREATE POLICY workouts_delete ON public.workouts
  FOR DELETE
  TO authenticated
  USING ((( SELECT auth.uid() AS uid) = user_id));

CREATE POLICY workouts_insert ON public.workouts
  FOR INSERT
  TO authenticated
  WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));

CREATE POLICY workouts_select ON public.workouts
  FOR SELECT
  TO authenticated
  USING ((( SELECT auth.uid() AS uid) = user_id));

CREATE POLICY workouts_update ON public.workouts
  FOR UPDATE
  TO authenticated
  USING ((( SELECT auth.uid() AS uid) = user_id))
  WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));
