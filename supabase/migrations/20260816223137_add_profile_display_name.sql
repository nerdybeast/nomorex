-- The author shown on anything a user publishes. Nullable: existing users have no
-- name until they set one, and the app renders a fallback label for those rows
-- rather than forcing a backfill of made-up names.
alter table public.profiles
  add column display_name text;

alter table public.profiles
  add constraint profiles_display_name_length
  check (display_name is null or char_length(btrim(display_name)) between 1 and 40);

-- workouts.user_id and programs.user_id both FK auth.users, which PostgREST cannot
-- traverse to reach public.profiles -- so `select('*, profiles(display_name)')` has
-- no relationship to embed. Adding a second FK straight to profiles gives it one.
-- profiles.id still FKs auth.users, so deleting a user cascades through profiles to
-- the workouts/programs rows exactly as before.
--
-- Every signup gets a profiles row from the handle_new_user trigger, but a user
-- created before that trigger existed would not have one and would break the FK, so
-- fill any gap first.
insert into public.profiles (id)
select u.id from auth.users u
where not exists (select 1 from public.profiles p where p.id = u.id);

alter table public.workouts
  add constraint workouts_user_id_profiles_fkey
  foreign key (user_id) references public.profiles (id) on delete cascade;

alter table public.programs
  add constraint programs_user_id_profiles_fkey
  foreign key (user_id) references public.profiles (id) on delete cascade;

-- Both FK columns are already covered by a leading-column index
-- (workouts_user_date_idx, idx_programs_user_id), so no new index is needed.

-- A viewer has to be able to read the display name of anyone whose workout or
-- program they can already see. Scoped to exactly those users rather than opening
-- profiles to every authenticated user: publishing something is what makes your
-- name visible. Merged into the single SELECT policy this schema uses per table
-- (see 20260813033442_merge_permissive_select_policies.sql) instead of adding a
-- second permissive policy.
drop policy if exists "Users can view own profile" on public.profiles;
create policy profiles_select on public.profiles
  for select to authenticated
  using (
    (select auth.uid()) = id
    or exists (
      select 1 from public.workouts w
      where w.user_id = profiles.id and w.is_public = true
    )
    or exists (
      select 1 from public.programs p
      where p.user_id = profiles.id and p.is_public = true and p.is_archived = false
    )
  );
