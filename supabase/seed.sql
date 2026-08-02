-- Predefined exercises visible to every user (exercises.is_predefined = true).
-- Runs after migrations on `supabase db reset` (local by default; see
-- supabase/config.toml [db.seed]). Keep in sync with the production
-- exercises table, since predefined rows are not managed via migrations.
insert into public.exercises (name, is_predefined) values
  ('Back Squat', true),
  ('Bench Press', true),
  ('Box Squat', true),
  ('Clean', true),
  ('Clean & Jerk', true),
  ('Close Grip Bench', true),
  ('Deadlift', true),
  ('Front Squat', true),
  ('Hang Clean', true),
  ('Hang Snatch', true),
  ('Jerk', true),
  ('Overhead Press', true),
  ('Pause Squat', true),
  ('Power Clean', true),
  ('Power Jerk', true),
  ('Power Snatch', true),
  ('Romanian Deadlift', true),
  ('Snatch', true),
  ('Sumo Deadlift', true);
