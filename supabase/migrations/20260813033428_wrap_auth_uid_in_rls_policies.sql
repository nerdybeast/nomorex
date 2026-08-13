-- Fix advisor finding: auth_rls_initplan
-- Wrap auth.uid() as (select auth.uid()) so it's evaluated once per query instead of
-- once per row. Semantics are unchanged.

-- public.exercises
drop policy if exists "Delete own custom exercises" on public.exercises;
create policy "Delete own custom exercises" on public.exercises
  for delete to authenticated
  using (((is_predefined = false) and (user_id = (select auth.uid()))));

drop policy if exists "Insert own custom exercises" on public.exercises;
create policy "Insert own custom exercises" on public.exercises
  for insert to authenticated
  with check (((is_predefined = false) and (user_id = (select auth.uid()))));

drop policy if exists "Read own custom exercises" on public.exercises;
create policy "Read own custom exercises" on public.exercises
  for select to authenticated
  using (((is_predefined = false) and (user_id = (select auth.uid()))));

drop policy if exists "Update own custom exercises" on public.exercises;
create policy "Update own custom exercises" on public.exercises
  for update to authenticated
  using (((is_predefined = false) and (user_id = (select auth.uid()))))
  with check (((is_predefined = false) and (user_id = (select auth.uid()))));

-- public.personal_bests
drop policy if exists "Delete own PRs" on public.personal_bests;
create policy "Delete own PRs" on public.personal_bests
  for delete to authenticated
  using ((user_id = (select auth.uid())));

drop policy if exists "Insert own PRs" on public.personal_bests;
create policy "Insert own PRs" on public.personal_bests
  for insert to authenticated
  with check ((user_id = (select auth.uid())));

drop policy if exists "Select own PRs" on public.personal_bests;
create policy "Select own PRs" on public.personal_bests
  for select to authenticated
  using ((user_id = (select auth.uid())));

drop policy if exists "Update own PRs" on public.personal_bests;
create policy "Update own PRs" on public.personal_bests
  for update to authenticated
  using ((user_id = (select auth.uid())))
  with check ((user_id = (select auth.uid())));

-- public.profiles
-- also add the missing "to authenticated" role scope (previously defaulted to PUBLIC,
-- inconsistent with every other table's ownership-policy convention).
drop policy if exists "Users can insert own profile" on public.profiles;
create policy "Users can insert own profile" on public.profiles
  for insert to authenticated
  with check (((select auth.uid()) = id));

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile" on public.profiles
  for update to authenticated
  using (((select auth.uid()) = id))
  with check (((select auth.uid()) = id));

drop policy if exists "Users can view own profile" on public.profiles;
create policy "Users can view own profile" on public.profiles
  for select to authenticated
  using (((select auth.uid()) = id));
