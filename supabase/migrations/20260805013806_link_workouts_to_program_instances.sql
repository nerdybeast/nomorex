-- ON DELETE SET NULL on both: deleting an instance or the source program
-- shouldn't delete the user's actual logged history, just orphan the
-- back-reference.
alter table public.workouts
  add column program_instance_id uuid references public.program_instances(id) on delete set null,
  add column program_day_id      uuid references public.program_days(id) on delete set null;

create index idx_workouts_program_instance_id on public.workouts (program_instance_id);
