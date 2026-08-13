-- Fix advisor finding: unindexed_foreign_keys

create index if not exists idx_personal_bests_exercise_id on public.personal_bests (exercise_id);

create index if not exists idx_program_days_user_id on public.program_days (user_id);

create index if not exists idx_program_exercises_exercise_id on public.program_exercises (exercise_id);
create index if not exists idx_program_exercises_user_id on public.program_exercises (user_id);

create index if not exists idx_program_instances_program_id on public.program_instances (program_id);

create index if not exists idx_program_sets_basis_exercise_id on public.program_sets (basis_exercise_id);
create index if not exists idx_program_sets_user_id on public.program_sets (user_id);

create index if not exists idx_program_weeks_user_id on public.program_weeks (user_id);

create index if not exists idx_workout_exercises_exercise_id on public.workout_exercises (exercise_id);
create index if not exists idx_workout_exercises_user_id on public.workout_exercises (user_id);

create index if not exists idx_workout_sets_basis_exercise_id on public.workout_sets (basis_exercise_id);
create index if not exists idx_workout_sets_user_id on public.workout_sets (user_id);

create index if not exists idx_workouts_program_day_id on public.workouts (program_day_id);
