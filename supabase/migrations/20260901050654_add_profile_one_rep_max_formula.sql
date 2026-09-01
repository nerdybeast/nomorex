-- Which formula the app uses to estimate a 1RM from a multi-rep personal best.
-- The three are the industry standards (Brzycki, Epley, Lander) and disagree by
-- several kilos at the same reps, so it's a per-user preference rather than a
-- constant.
--
-- NOT NULL with a default rather than nullable: handle_new_user inserts only
-- (id), so a new signup would violate a bare NOT NULL, and every read path
-- wants a concrete formula. The default also backfills existing rows onto
-- Brzycki, which is the app default and the most accurate at the low rep
-- counts most PRs are set at.
alter table public.profiles
  add column one_rep_max_formula text not null default 'brzycki';

alter table public.profiles
  add constraint profiles_one_rep_max_formula_check
  check (one_rep_max_formula = any (array['brzycki'::text, 'epley'::text, 'lander'::text]));
