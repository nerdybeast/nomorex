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

-- Local-only test users, already email-confirmed. Password for both: 123456
-- auth.users must be seeded directly (GoTrue has no seed-file mechanism of
-- its own); this fires the on_auth_user_created trigger, which creates the
-- matching public.profiles row for each. Never run this against a linked
-- project — it writes real auth records with a known, shared password.
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
) values
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'a@a.com',
   extensions.crypt('123456', extensions.gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'b@b.com',
   extensions.crypt('123456', extensions.gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', '');

insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
select gen_random_uuid(), id, id::text, jsonb_build_object('sub', id::text, 'email', email),
  'email', now(), now(), now()
from auth.users
where email in ('a@a.com', 'b@b.com');
