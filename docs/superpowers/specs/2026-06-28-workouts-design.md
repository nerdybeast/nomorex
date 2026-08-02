# Workouts (Sessions) — Design

**Date:** 2026-06-28
**Status:** Approved (design); implementation plan pending

## Problem

The app lets a user track personal bests per exercise, but has no concept of a
**workout** — a single training session made up of exercises, each with
prescribed sets. Olympic weightlifting programs (the target use case) prescribe
sets where each set's load is either a **percentage of the lifter's max** for
that lift or a **static weight**. There is no way to plan such a session, see the
working weights resolved from one's maxes, or check off sets while performing it.

Goal: let a user **plan** a dated workout (exercises + sets, with per-set
percentage or absolute loads) and then **execute** it (see resolved working
weights, check off sets, optionally log actuals).

## Decisions (from brainstorming)

| Decision | Choice |
|----------|--------|
| Primary purpose | **Both** — plan a session, then execute it |
| Reuse model | **Dated session + duplicate** (no template/instance concept) |
| Set weight modes | **Percentage of own-lift max** OR **static/absolute weight** |
| Per-set varying % | **Yes** — each set carries its own percentage |
| `%` reference lift | Always the set's **own** exercise (no cross-lift %) |
| `%` max source | User's **recorded 1-rep PR** for that exercise (`personal_bests` where `reps = 1`) |
| Set storage shape | **One row per set** (Approach A), normalized 3-table model |
| Qualitative cues / EMOM / rep ranges | Free-text **notes**, not structured fields |

### Out of scope (YAGNI — schema must not preclude these)

Reusable templates/programs, EMOM / time-based sets as structured data, rep
ranges as structured data, percentage referencing a *different* lift's max, and
auto-promoting a big execution result into a new personal best. All are deferred;
none are blocked by this schema.

## Current State (verified)

- Flutter + hosted Supabase (clients talk to Supabase **directly**, so RLS is the
  only protection), Riverpod with codegen (`@Riverpod`), `go_router` with a
  `StatefulShellRoute.indexedStack` tab shell (`lib/app.dart`).
- Feature-based layout: `lib/features/<feature>/{models,providers,screens}`.
- Existing tables: `exercises` (predefined + per-user custom), `personal_bests`
  (`weight_kg`, `reps`, `exercise_id`, `user_id` — effectively the 1RM source),
  `profiles` (holds unit preference).
- Weight is stored in **kg**; UI converts via `core/utils/weight_converter.dart`
  and a kg/lbs toggle driven by `unitPreferenceProvider`.
- Models are **hand-written** plain Dart classes with `fromJson` (no freezed).
- Providers follow a pattern: `ref.watch(authStateProvider)` to rebuild on auth
  change, then `invalidateSelf()` + `await future` after a mutation
  (`lib/features/personal_bests/providers/personal_bests_provider.dart`).
- An autocomplete **exercise picker with "add custom"** already exists, currently
  private inside `lib/features/personal_bests/screens/add_pr_screen.dart`
  (`_ExercisePicker`).
- Supabase migrations workflow is documented in
  `docs/superpowers/specs/2026-06-18-supabase-migrations-cicd-design.md`
  (schema-as-code; every table gets RLS; default ownership policy
  `auth.uid() = user_id`).

## Architecture

### 1. Data model — three normalized tables

`user_id` is **denormalized onto all three tables** so every RLS policy is the
project's standard `auth.uid() = user_id` form (uniform and index-friendly),
rather than `EXISTS`-on-parent subqueries. Cost: child inserts must set
`user_id`.

```
workouts
  id          uuid pk default gen_random_uuid()
  user_id     uuid not null references auth.users(id)
  title       text not null
  date        date not null
  notes       text
  created_at  timestamptz not null default now()
  updated_at  timestamptz not null default now()

workout_exercises
  id            uuid pk default gen_random_uuid()
  workout_id    uuid not null references workouts(id) on delete cascade
  user_id       uuid not null references auth.users(id)
  exercise_id   uuid not null references exercises(id)
  position      int  not null            -- ordering within the workout
  notes         text                     -- free-text cue: "build to a heavy triple",
                                          -- "15 min EMOM @70%", "challenging load"
  created_at    timestamptz not null default now()

workout_sets
  id                   uuid pk default gen_random_uuid()
  workout_exercise_id  uuid not null references workout_exercises(id) on delete cascade
  user_id              uuid not null references auth.users(id)
  position             int  not null     -- ordering within the exercise
  target_reps          int
  weight_mode          text not null check (weight_mode in ('percentage','absolute'))
  percentage           numeric           -- used when weight_mode='percentage' (e.g. 80.0)
  absolute_weight_kg   numeric           -- used when weight_mode='absolute'
  note                 text
  -- execution fields:
  completed            boolean not null default false
  actual_weight_kg     numeric
  actual_reps          int
  created_at           timestamptz not null default now()
  constraint weight_mode_value check (
       (weight_mode = 'percentage' and percentage is not null)
    or (weight_mode = 'absolute'   and absolute_weight_kg is not null)
  )
```

`percentage` always refers to the 1RM of the parent `workout_exercise`'s
`exercise_id` — no cross-lift reference column (deliberately out of scope).

**RLS** (per documented rule): each table gets `enable row level security` plus
owner policies for `select / insert / update / delete` using
`((select auth.uid()) = user_id)` (and matching `with check` on insert/update).

**Indexes:** `workouts(user_id, date desc)`, `workout_exercises(workout_id)`,
`workout_sets(workout_exercise_id)`.

**Migration:** one new file `supabase/migrations/<timestamp>_workouts.sql`,
created and validated via the existing Supabase CLI workflow
(`supabase migration new` → write SQL → `supabase db reset` to prove it applies
from scratch).

### 2. Percentage → working-weight resolution

A new provider `oneRepMaxProvider` reads `personal_bests` where `reps = 1` and
reduces to the **maximum `weight_kg` per `exercise_id`**, yielding
`Map<String exerciseId, double oneRepMaxKg>`.

A pure function resolves a set's load:

```
resolvedKg(set, oneRepMaxKg) =
  weight_mode == 'absolute'   -> absolute_weight_kg
  weight_mode == 'percentage' -> oneRepMaxKg == null ? null
                                                     : percentage/100 * oneRepMaxKg
```

When a percentage set has no 1RM available, the UI shows the percentage with a
hint (e.g. **"80% — set a 1RM"**) and no resolved number. Display weight is
converted to the user's unit via the existing `weight_converter` / unit
preference.

### 3. Flutter feature module — `lib/features/workouts/`

```
models/
  workout.dart            -- id, userId, title, date, notes, timestamps,
                          --   plus optional nested exercises
  workout_exercise.dart   -- id, workoutId, exerciseId, exerciseName, position,
                          --   notes, plus optional nested sets
  workout_set.dart        -- all set columns above
providers/
  workouts_provider.dart        -- @Riverpod(keepAlive: true) list for current user
  workout_detail_provider.dart  -- family by workoutId: full nested workout
  one_rep_max_provider.dart     -- Map<exerciseId, oneRepMaxKg>
screens/
  workouts_screen.dart          -- list tab
  edit_workout_screen.dart      -- create / edit plan
  workout_detail_screen.dart    -- view + execute
widgets/
  set_builder.dart, set_tile.dart, (and supporting widgets as needed)
```

Models are hand-written plain Dart with `fromJson`, matching the existing style.
Providers use codegen and the existing `authStateProvider` watch +
`invalidateSelf()` + `await future` mutation pattern.

**Shared widget extraction:** the `_ExercisePicker` autocomplete (autocomplete +
"add custom exercise") is extracted from `add_pr_screen.dart` into a shared,
public widget (e.g. `lib/features/exercises/widgets/exercise_picker.dart`) and
reused by both the add-PR screen and the workout editor. This is a targeted
refactor of code we're directly building on — not unrelated cleanup.

### 4. Navigation

Add a **third tab** to the `StatefulShellRoute` (Home / PRs / **Workouts**) and a
matching `NavigationDestination` in `app_shell.dart`. New routes in
`AppConstants` + `app.dart`:

```
routeWorkouts      = '/shell/workouts'   -- list tab
routeWorkoutNew    = '/workouts/new'     -- create
routeWorkoutDetail = '/workouts/:id'     -- view + execute
routeWorkoutEdit   = '/workouts/:id/edit'
```

### 5. Screens & flows

- **Workouts list (tab):** user's workouts sorted by `date desc`; each card shows
  title, date, exercise count. FAB → new workout. Card overflow menu:
  **Duplicate** (deep-copies workout + exercises + sets to a new date — the
  "reuse a weekly program" path; copied sets reset `completed`/actuals) and
  **Delete** (FK cascade removes children).
- **Edit / Create:** title field + date picker; an ordered, **reorderable** list
  of exercises added via the shared exercise picker. Each exercise row has a
  notes field and a list of sets. A **set builder** adds many sets quickly —
  shorthand `"4 x 2 @ 65-68-71-68"` parses to 4 set rows (4 sets × 2 reps at the
  four listed percentages); a single percentage (`"3 x 5 @ 80"`) applies to all.
  Each resulting set row is individually editable: target reps, a `% / kg` mode
  toggle, and the value. Absolute-weight entry respects the kg/lbs unit
  preference like `AddPrScreen`. Saving requires title + date; exercises are
  optional (an empty plan is allowed).
- **Detail / Execute:** the plan rendered read-only with **resolved working
  weights** per set (or the "set a 1RM" hint). A per-set checkbox toggles
  `completed` and persists immediately. An optional "log actual" control reveals
  `actual_weight_kg` / `actual_reps` inputs, prefilled with the target/resolved
  values. Also exposes **Duplicate**.

### 6. Set-builder shorthand parser

Pure, unit-tested function. Grammar (informal):

```
"<sets> x <reps> @ <pct>[-<pct>...]"   e.g. "4 x 2 @ 65-68-71-68"  -> percentage sets
"<sets> x <reps> @ <pct>"              e.g. "3 x 5 @ 80"           -> same pct each set
```

- `sets` and `reps` are integers; `reps` populates `target_reps`.
- One percentage → applied to every set. A hyphenated list → must have length
  equal to `sets`; each value maps to one set in order. A length mismatch is a
  validation error surfaced inline.
- The shorthand only produces **percentage** sets; absolute-weight sets are added
  via the per-set `% / kg` toggle after the fact (or by adding a blank set and
  switching its mode). This keeps the parser small; the toggle covers the static
  case.

## Components & Responsibilities

| Unit | Purpose | Depends on |
|------|---------|-----------|
| `supabase/migrations/<ts>_workouts.sql` | 3 tables + RLS + indexes | existing `exercises`, auth |
| `workouts_provider` | List current user's workouts | auth, Supabase |
| `workout_detail_provider` (family) | Nested workout + exercises + sets | auth, Supabase |
| `one_rep_max_provider` | `Map<exerciseId, 1RM kg>` from PRs | `personal_bests` |
| resolve-weight fn | percentage/absolute → kg | one-rep-max map |
| set-builder parser | shorthand → set rows | none (pure) |
| `exercise_picker` (shared widget) | pick/add exercise | `exercises` provider |
| `workouts_screen` | list, new, duplicate, delete | workouts_provider |
| `edit_workout_screen` | build/edit plan | detail provider, picker, parser |
| `workout_detail_screen` | view + execute (check off, log actuals) | detail + one-rep-max |

## Error Handling

- Provider mutations wrapped in try/catch; errors surfaced via the screens'
  existing `_error` text pattern.
- Deleting a workout or exercise relies on FK `on delete cascade` for children.
- Percentage set with no 1RM resolves to `null` → UI shows the "set a 1RM" hint
  rather than a wrong number.
- Save validation: title + date required; set-builder length mismatch rejected
  inline; absolute set requires a weight, percentage set requires a percentage
  (mirrors the DB `check` constraint).
- Auth change rebuilds providers (watch `authStateProvider`) to prevent
  cross-user data leaks, consistent with existing providers.

## Testing

- **Unit:** percentage→weight resolution (incl. missing-1RM → null); set-builder
  parser (single pct, per-set pct list, length-mismatch error, reps parsing);
  model `fromJson` for all three models; reuse existing `weight_converter` for
  kg/lbs round-trips.
- **Migration:** `supabase db reset` proves the migration applies from scratch;
  `supabase db lint` checks RLS (per the migrations CI workflow).
- Footprint stays focused on the bug-prone pure logic, matching the repo's
  current light test setup.

## Implementation Order (high level)

1. Migration: `workouts`, `workout_exercises`, `workout_sets` + RLS + indexes;
   validate with `supabase db reset`.
2. Models (`workout`, `workout_exercise`, `workout_set`) + `fromJson` tests.
3. Providers: `one_rep_max_provider`, `workouts_provider`,
   `workout_detail_provider`; resolve-weight fn + tests.
4. Extract shared `exercise_picker` widget; repoint `add_pr_screen`.
5. Navigation: 3rd shell tab + routes + `AppConstants`.
6. `workouts_screen` (list / new / duplicate / delete).
7. `set_builder` parser + widget (+ parser tests); `edit_workout_screen`.
8. `workout_detail_screen` (resolved weights, check-off, log actuals).
9. End-to-end pass on web; verify RLS isolates per user.
