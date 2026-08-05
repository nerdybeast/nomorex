-- day_number is intentionally NOT unique per week: two program_days can
-- share day_number = 3 (e.g. an AM and PM session both labeled "Day 3") —
-- each still gets its own `position` and becomes its own separate
-- `workouts` row at materialization, landing on the same calendar date.
create table public.program_days (
  id               uuid primary key default gen_random_uuid(),
  program_id       uuid not null references public.programs(id) on delete cascade, -- denormalized for direct ordering/query
  program_week_id  uuid not null references public.program_weeks(id) on delete cascade,
  user_id          uuid not null references auth.users(id) on delete cascade,
  day_number       integer not null, -- display-only grouping within the week (e.g. 1 = "Day 1"/"Monday")
  title            text not null,    -- "Day 1", "Monday", "Athletic Power Day"
  is_rest_day      boolean not null default false,
  notes            text,
  position         integer not null, -- GLOBAL order across the whole program; drives materialization order
  created_at       timestamptz not null default now(),
  unique (program_id, position)
);

alter table public.program_days enable row level security;
create index idx_program_days_program_week_id on public.program_days (program_week_id);
create index idx_program_days_program_id on public.program_days (program_id);

create policy program_days_select on public.program_days
  for select to authenticated using ((select auth.uid()) = user_id);
create policy program_days_insert on public.program_days
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy program_days_update on public.program_days
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy program_days_delete on public.program_days
  for delete to authenticated using ((select auth.uid()) = user_id);

create policy program_days_select_public on public.program_days
  for select to authenticated using (exists (
    select 1 from public.programs p where p.id = program_days.program_id and p.is_public = true
  ));
