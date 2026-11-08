-- Lead the copy-source indexes with the foreign-key column.
--
-- 20261013023308_add_content_copies.sql indexed (user_id, copied_from_*_id)
-- for the "You've saved this" copy-count queries. Those filter on both
-- columns, but the self-referencing foreign keys
-- (workouts_copied_from_workout_id_fkey, programs_copied_from_program_id_fkey,
-- both ON DELETE SET NULL) look copies up by copied_from_*_id alone when a
-- source row is deleted. An index can't be searched efficiently without its
-- leading column, so each such delete seq-scanned the table, and the Supabase
-- advisor reported both foreign keys as unindexed (lint 0001).
--
-- Swapping the column order lets one index serve both: the copy-count query
-- is equality on both columns, and the FK action gets its leading column.
-- The partial predicate still applies, since `col = $1` implies
-- `col IS NOT NULL`.

drop index if exists public.idx_workouts_copied_from_workout;
create index idx_workouts_copied_from_workout
  on public.workouts (copied_from_workout_id, user_id)
  where copied_from_workout_id is not null;

drop index if exists public.idx_programs_copied_from_program;
create index idx_programs_copied_from_program
  on public.programs (copied_from_program_id, user_id)
  where copied_from_program_id is not null;
