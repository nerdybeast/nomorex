alter table public.profiles
  drop constraint profiles_unit_preference_check;

alter table public.profiles
  add constraint profiles_unit_preference_check
  check (unit_preference = any (array['kg'::text, 'lbs'::text, 'both'::text]));

alter table public.profiles
  alter column unit_preference set default 'both'::text;
