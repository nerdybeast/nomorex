-- Baseline schema: profiles, exercises, personal_bests.
--
-- These tables predate migration tracking — they were created directly in the
-- cloud project before `supabase/migrations/` existed, so a from-scratch
-- `supabase db reset` had nothing to create them and the later workouts
-- migration failed on `references public.exercises`. This migration captures
-- that pre-existing schema (introspected from the live project) so migrations
-- replay cleanly from an empty database. It is ordered before the workouts
-- migration.

-- profiles: one row per auth user, holding app preferences
create table public.profiles (
  id              uuid primary key references auth.users (id) on delete cascade,
  unit_preference text not null default 'kg' check (unit_preference in ('kg', 'lbs')),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- exercises: predefined (global) or custom (owned by a user)
create table public.exercises (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  is_predefined boolean not null default false,
  user_id       uuid references auth.users (id) on delete cascade,
  created_at    timestamptz not null default now(),
  constraint exercises_predefined_check check (
        (is_predefined = true  and user_id is null)
     or (is_predefined = false and user_id is not null)
  )
);

-- personal_bests: a user's best lift for an exercise
create table public.personal_bests (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  exercise_id uuid not null references public.exercises (id) on delete restrict,
  weight_kg   numeric not null check (weight_kg > 0),
  reps        integer not null default 1 check (reps > 0),
  date        date not null default current_date,
  notes       text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index idx_exercises_user_id        on public.exercises (user_id);
create index idx_personal_bests_user_id   on public.personal_bests (user_id);
create index idx_personal_bests_updated_at on public.personal_bests (user_id, updated_at desc);

-- Create a profile row automatically when a new auth user signs up.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  insert into public.profiles (id) values (new.id);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Keep updated_at current on personal_bests updates.
create function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin new.updated_at = now(); return new; end;
$$;

create trigger set_personal_bests_updated_at
  before update on public.personal_bests
  for each row execute function public.set_updated_at();

-- Row level security
alter table public.profiles       enable row level security;
alter table public.exercises      enable row level security;
alter table public.personal_bests enable row level security;

-- profiles: owner-scoped (default PUBLIC role, matching live project)
create policy "Users can view own profile" on public.profiles for select
  using (auth.uid() = id);
create policy "Users can insert own profile" on public.profiles for insert
  with check (auth.uid() = id);
create policy "Users can update own profile" on public.profiles for update
  using (auth.uid() = id) with check (auth.uid() = id);

-- exercises: predefined readable by all authenticated; custom owner-scoped
create policy "Read predefined exercises" on public.exercises for select
  to authenticated using (is_predefined = true);
create policy "Read own custom exercises" on public.exercises for select
  to authenticated using (is_predefined = false and user_id = auth.uid());
create policy "Insert own custom exercises" on public.exercises for insert
  to authenticated with check (is_predefined = false and user_id = auth.uid());
create policy "Update own custom exercises" on public.exercises for update
  to authenticated using (is_predefined = false and user_id = auth.uid())
  with check (is_predefined = false and user_id = auth.uid());
create policy "Delete own custom exercises" on public.exercises for delete
  to authenticated using (is_predefined = false and user_id = auth.uid());

-- personal_bests: owner-scoped
create policy "Select own PRs" on public.personal_bests for select
  to authenticated using (user_id = auth.uid());
create policy "Insert own PRs" on public.personal_bests for insert
  to authenticated with check (user_id = auth.uid());
create policy "Update own PRs" on public.personal_bests for update
  to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "Delete own PRs" on public.personal_bests for delete
  to authenticated using (user_id = auth.uid());
