-- One user's "run" of a program, created when they hit Start. program_id
-- uses ON DELETE RESTRICT as a backstop for the programs.is_archived
-- soft-delete decision: the app itself never hard-deletes a program with
-- instance history.
create table public.program_instances (
  id           uuid primary key default gen_random_uuid(),
  program_id   uuid not null references public.programs(id) on delete restrict,
  user_id      uuid not null references auth.users(id) on delete cascade,
  started_at   date not null default current_date,
  status       text not null default 'active' check (status in ('active','completed','abandoned')),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

alter table public.program_instances enable row level security;
create index idx_program_instances_user_id on public.program_instances (user_id);

create trigger set_program_instances_updated_at
  before update on public.program_instances
  for each row execute function public.set_updated_at();

-- Standard owner-only CRUD; instances are never public even if the source
-- program is.
create policy program_instances_select on public.program_instances
  for select to authenticated using ((select auth.uid()) = user_id);
create policy program_instances_insert on public.program_instances
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy program_instances_update on public.program_instances
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy program_instances_delete on public.program_instances
  for delete to authenticated using ((select auth.uid()) = user_id);
