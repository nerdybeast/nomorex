create table public.program_weeks (
  id          uuid primary key default gen_random_uuid(),
  program_id  uuid not null references public.programs(id) on delete cascade,
  user_id     uuid not null references auth.users(id) on delete cascade, -- denormalized, per CLAUDE.md RLS convention
  week_number integer not null,
  label       text,   -- e.g. "Eccentrics Week 1/2", "Loading Week 2/6"
  notes       text,
  position    integer not null,
  created_at  timestamptz not null default now(),
  unique (program_id, week_number)
);

alter table public.program_weeks enable row level security;
create index idx_program_weeks_program_id on public.program_weeks (program_id);

create policy program_weeks_select on public.program_weeks
  for select to authenticated using ((select auth.uid()) = user_id);
create policy program_weeks_insert on public.program_weeks
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy program_weeks_update on public.program_weeks
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy program_weeks_delete on public.program_weeks
  for delete to authenticated using ((select auth.uid()) = user_id);

create policy program_weeks_select_public on public.program_weeks
  for select to authenticated using (exists (
    select 1 from public.programs p where p.id = program_weeks.program_id and p.is_public = true
  ));
