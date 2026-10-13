# Quickstart: Validate Save & Start from Community

## Prerequisites

- Docker + Supabase CLI; `supabase start`
- `supabase db reset` (local only) — applies the new migration and seed
- `.env.local.json` from `supabase status`
- Seed includes a **public** workout and a **public** program owned by `b@b.com` (added by this
  feature; the current seed has no public content). Seeded users: `a@a.com` / `b@b.com`, password
  `123456`.

## Automated checks

```bash
supabase db lint
flutter analyze
flutter test                                   # unit + widget
flutter test test/community                    # focused
./scripts/e2e.sh                               # includes the new community copy E2E file
```

## Manual scenarios (web or device)

`flutter run --dart-define-from-file=.env.local.json`, sign in as `a@a.com`.

| # | Steps | Expected |
|---|---|---|
| 1 | Community → b's public workout → **Save to my workouts** → **View** | Copy in Workouts list with "Copied from <b's name>" badge; same exercises/sets/notes; percentage sets resolve against **a's** 1RMs (spec US1). |
| 2 | Back on b's workout | "You've saved this 1 time" hint; Save still enabled (FR-013). |
| 3 | b's workout → **Start workout** | Lands in an in-progress session of a new copy; it appears under in-progress on Home (US2). |
| 4 | Open a copy → Edit | Public switch disabled with the explanation (FR-008). |
| 5 | Duplicate a copy from the Workouts list | Duplicate also shows the badge; Public still disabled (FR-008a). |
| 6 | Community → b's public program → **Save to my programs** | Full copy in Programs, all weeks/days (incl. rest days) in order, badge shown (US3). |
| 7 | b's program → **Start program** → pick today | Lands on the program run; Home shows it under Current Programs; generated workouts show the badge (US4, FR-008a). |
| 8 | Sign in as b, make the workout private / archive the program; sign back in as a | a's copies unchanged (FR-009); badge still names b. |
| 9 | Check Exercises picker as a | Any of b's custom lifts now exist once each in a's catalog — no duplicates on re-save (SC-006). |
| 10 | Own content in Community (a makes a workout public) | No Save/Start on own items (FR-018). |

## Server-side guard spot checks (SQL editor, local stack, as an authenticated user)

- `update workouts set is_public = true where is_copy` → fails the check constraint.
- `update workouts set is_copy = false where is_copy` → fails with `copy_is_permanent`.
- `select copy_program('<archived public program id>')` → `archived:` error, no rows created.
