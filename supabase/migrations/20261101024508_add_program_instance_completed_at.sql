-- When a program run was ended (completed or abandoned). Null while active.
-- Additive and nullable so the app version already in production keeps working.
alter table public.program_instances
  add column completed_at timestamptz;
