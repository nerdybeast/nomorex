-- A Program is authoring-time data: a reusable, multi-week template a user
-- builds once and can "start" repeatedly (see program_instances). No
-- user-facing hard delete: "Delete" in the UI archives instead
-- (is_archived = true), which is always allowed and reversible. A real
-- DELETE is never issued by the app for a program with instance history —
-- program_instances.program_id uses ON DELETE RESTRICT as a database-level
-- backstop, not the primary mechanism.
create table public.programs (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  name        text not null,
  description text,
  is_public   boolean not null default false,
  is_archived boolean not null default false,
  archived_at timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

alter table public.programs enable row level security;

create index idx_programs_user_id on public.programs (user_id);
create index idx_programs_active on public.programs (user_id, created_at desc) where is_archived = false;
create index idx_programs_public on public.programs (created_at desc) where is_public = true and is_archived = false;

create trigger set_programs_updated_at
  before update on public.programs
  for each row execute function public.set_updated_at();

create policy programs_select on public.programs
  for select to authenticated using ((select auth.uid()) = user_id);
create policy programs_select_public on public.programs
  for select to authenticated using (is_public = true);
create policy programs_insert on public.programs
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy programs_update on public.programs
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy programs_delete on public.programs
  for delete to authenticated using ((select auth.uid()) = user_id);
