-- Reject set values no lifter could mean (#36): zero or negative reps, a 0%
-- or 900% set, negative loads. The app's steppers already stop these, but
-- clients write to PostgREST directly, so an old build, a bug or a hand-made
-- request could store them, and they'd flow into 1RM and percentage maths.
--
-- Already in place, so not repeated here:
--   personal_bests: reps > 0, weight_kg > 0 (20260802012717_remote_schema.sql)
--   *_sets: weight_mode in ('percentage','absolute','open'), the value each
--           mode requires, range tops >= their bottoms, RPE within 1..10
--           (20261104040520_add_set_ranges_rpe_and_open_load.sql)
--
-- Bounds match the clients that write these columns:
--   reps:        SetEditor's Reps stepper floors at 1; ai_import/normalize.ts
--                accepts 1..1000.
--   percentage:  above 0 and at most 200, the range normalize.ts accepts
--                (0.5..200); SetEditor's %1RM stepper uses the same bounds.
--                Supramaximal work (105-110% holds, partials) stays possible.
--   loads:       0 or more. 0 kg is a real prescription (an empty-bar or
--                bodyweight set entered before open-load sets existed), so
--                only negatives are refused.
--   actual_reps: 0 or more. A missed set logged as 0 reps is a real result.
--
-- Each constraint is added NOT VALID (enforced on new writes at once, without
-- scanning) and then validated, which scans existing rows under a lock that
-- doesn't block reads or writes. If a production row breaks a rule, VALIDATE
-- fails and the whole migration rolls back, leaving the schema as it was.

-- ---------------------------------------------------------------------------
-- program_sets
-- ---------------------------------------------------------------------------

alter table public.program_sets
  add constraint program_sets_target_reps_positive
    check (target_reps is null or target_reps >= 1) not valid,
  add constraint program_sets_percentage_bounds check (
    (percentage is null or (percentage > 0 and percentage <= 200))
    and (percentage_max is null or percentage_max <= 200)
  ) not valid,
  add constraint program_sets_absolute_weight_nonnegative
    check (absolute_weight_kg is null or absolute_weight_kg >= 0) not valid;

alter table public.program_sets validate constraint program_sets_target_reps_positive;
alter table public.program_sets validate constraint program_sets_percentage_bounds;
alter table public.program_sets validate constraint program_sets_absolute_weight_nonnegative;

-- ---------------------------------------------------------------------------
-- workout_sets (the same prescription rules, plus the logged results)
-- ---------------------------------------------------------------------------

alter table public.workout_sets
  add constraint workout_sets_target_reps_positive
    check (target_reps is null or target_reps >= 1) not valid,
  add constraint workout_sets_percentage_bounds check (
    (percentage is null or (percentage > 0 and percentage <= 200))
    and (percentage_max is null or percentage_max <= 200)
  ) not valid,
  add constraint workout_sets_absolute_weight_nonnegative
    check (absolute_weight_kg is null or absolute_weight_kg >= 0) not valid,
  add constraint workout_sets_actual_weight_nonnegative
    check (actual_weight_kg is null or actual_weight_kg >= 0) not valid,
  add constraint workout_sets_actual_reps_nonnegative
    check (actual_reps is null or actual_reps >= 0) not valid;

alter table public.workout_sets validate constraint workout_sets_target_reps_positive;
alter table public.workout_sets validate constraint workout_sets_percentage_bounds;
alter table public.workout_sets validate constraint workout_sets_absolute_weight_nonnegative;
alter table public.workout_sets validate constraint workout_sets_actual_weight_nonnegative;
alter table public.workout_sets validate constraint workout_sets_actual_reps_nonnegative;
