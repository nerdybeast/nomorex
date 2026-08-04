# Program Support — Implementation Plan

**Status:** Draft — planning only, no code changes made in this pass. This is the working plan to hand to Claude Code for implementation.
**Inputs:** `docs/research/zt-6-week-positional.md`, `docs/research/zt-strong-like-bull-4-week.md`, `docs/research/zt-6-week-program.md`, `docs/research/zt-8-week.md` — four real-world weightlifting programs used as the reference target for "what must this feature be able to express."
**Grounded against:** the current codebase as of this writing (`lib/features/workouts/*`, `supabase/migrations/*`, `supabase/seed.sql`, `lib/app.dart`, `lib/core/constants/app_constants.dart`).

---

## 1. Goal

Let a user author a reusable, multi-week, multi-day training **program** (a template), then **start** it, which schedules it onto their calendar as a series of ordinary logged workouts they follow day to day — the same way the four ZT programs are structured: N weeks, each with one or more days, each day with one or more exercises, each exercise with one or more sets that are either an absolute weight or a percentage of some lift's max.

## 2. Core design decision: programs *generate* workouts, they don't replace them

The single most important architectural choice in this plan: **a Program is authoring-time data. A Workout is still the only runtime/logged entity.** "Starting" a program is a one-time materialization step that bulk-creates ordinary `workouts` / `workout_exercises` / `workout_sets` rows from the template. After that, the user is just looking at normal workouts through the screens that already exist today (`WorkoutDetailScreen`, `EditWorkoutScreen`, `SetEditor`, `set_resolver.dart`, etc.) — nothing about logging, completing sets, or viewing workout history needs to change.

This keeps the blast radius small:

- No new "program runtime" concept, no new set-completion logic, no new dashboard logic for "what's due today" beyond what workouts already provide (they have a `date`).
- `resolveSetWeightKg()` and the whole logged-workout experience are reused as-is.
- The only genuinely new runtime concept is the **percentage basis exercise** (Section 4), which is needed independent of programs — several ZT sets are a percentage of a *different* lift's max than the one being performed, and today's schema can't express that at all, in a program or a plain workout.

Programs are therefore additive: a new `programs` feature module that reads/writes new tables, plus one new nullable linkage on `workouts` back to the program that generated it, plus the basis-exercise column on sets.

## 3. Terminology used in this plan

| Term | Meaning |
|---|---|
| **Program** | The reusable template a user authors (e.g. "ZT 6 Week Program"). Owned by a user, optionally public. |
| **Program Week** | A labeled group of days within a program (e.g. "Loading Week 2/6"). Carries the phase label/notes the research docs captured. |
| **Program Day** | One planned session (e.g. "Day 1", "Tuesday", "Athletic Power Day"). Maps 1:1 to a future `workouts` row once started. |
| **Program Exercise / Program Set** | Template equivalents of `workout_exercises` / `workout_sets` — same shape, no logging fields (`completed`, `actual_*`). |
| **Program Instance** | One user's "run" of a program — created when they hit Start. Owns the batch of materialized workouts. |
| **Basis exercise** | The exercise whose 1RM a percentage set is calculated against. Defaults to the exercise being performed (today's only behavior); can now be a different exercise (e.g. Front Squat sets at "% of Clean & Jerk"). |

---

## 4. Phase 1 — Percentage "basis exercise" (ship first, independent of programs)

This unblocks real data entry for plain workouts today and is a prerequisite for programs, since program sets need the same capability. Small surface area, do this first.

### 4.1 Schema change

```sql
alter table public.workout_sets
  add column basis_exercise_id uuid references public.exercises(id);
```

- Nullable. `null` preserves today's exact behavior (percentage of the set's own exercise's 1RM).
- No `on delete` action specified deliberately → discuss with team; recommend `on delete set null` so deleting a custom exercise that was used as a basis doesn't fail/cascade oddly. (`workout_exercises.exercise_id` currently has no `on delete` clause either — matches existing convention of leaving it to default `NO ACTION`, but `basis_exercise_id` is more likely to go stale since it's not "the" exercise of the row it's on. Recommend explicit `ON DELETE SET NULL` here even though the existing FK doesn't use one.)
- The public-workout RLS extension in `20260802213619_add_workout_visibility.sql` added a policy `"Read exercises used in public workouts"` scoped to `workout_exercises.exercise_id`. It needs a sibling clause (or an `OR`) covering `workout_sets.basis_exercise_id`, otherwise a public workout's viewer will see `null` for the basis exercise's name if it's a custom exercise owned by someone else:

```sql
-- extend (or add alongside) the existing policy
CREATE POLICY "Read exercises used as a public workout's set basis" ON public.exercises
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.workout_sets ws
    JOIN public.workout_exercises we ON we.id = ws.workout_exercise_id
    JOIN public.workouts w ON w.id = we.workout_id
    WHERE ws.basis_exercise_id = exercises.id AND w.is_public = true
  ));
```

### 4.2 Model change

`lib/features/workouts/models/workout_set.dart`:

- Add `final String? basisExerciseId;` and `final String? basisExerciseName;`.
- `fromJson` needs the nested basis exercise name. Since `workout_sets` will now have exactly one FK to `exercises` (via `basis_exercise_id` — `workout_sets` has no direct `exercise_id` today), the nested select `workout_sets(*, exercises(name))` is unambiguous. Update the parent select in `workout_detail_provider.dart` accordingly:

```dart
.select('*, workout_exercises(*, exercises(name), workout_sets(*, exercises(name)))')
```

  Read the joined name defensively (`json['exercises']?['name']`) since `basis_exercise_id` is nullable and the join can be absent.

### 4.3 Resolver

`resolveSetWeightKg()` in `lib/features/workouts/utils/set_resolver.dart` **does not need to change** — it already just takes whatever `oneRepMaxKg` the caller passes in. The change is entirely at the call site: instead of always looking up `oneRepMaxProvider[workoutExercise.exerciseId]`, look up `oneRepMaxProvider[set.basisExerciseId ?? workoutExercise.exerciseId]`. Confirmed against the current codebase: there is exactly one call site today, in `lib/features/workouts/screens/workout_detail_screen.dart` (`edit_workout_screen.dart` doesn't call it) — update it there.

### 4.4 UI

`lib/features/workouts/widgets/set_editor.dart`:

- `ParsedSet` gets a third field: `final String? basisExerciseId;`.
- The "Add sets (%)" dialog (`_showPercentageSetDialog`) gets a new control above the per-set %1RM steppers: a dropdown/autocomplete labeled "Based on" defaulting to **"This exercise"** (`null`), populated from `exercisesProvider` (`lib/features/exercises/providers/exercises_provider.dart`'s `ExercisesNotifier` — confirmed this is the existing provider backing the add-exercise picker; returns `List<Exercise>` with `id`/`name`/`isPredefined`/`userId`, and `Exercise` already has a `toString()` returning `name`, which drops straight into a `DropdownButton<Exercise?>` or similar without extra mapping). One basis selection applies to the whole batch of sets being added in that dialog (matches how the ZT programs use one basis per exercise-block, not per individual set).
- `_SetRow` display: when `set.basisExerciseId != null` and differs from the owning exercise, render `"${pct}% of ${basisExerciseName}"` instead of the current `"${pct}% of 1RM"`.
- `WorkoutDetailNotifier.addPercentageSets` passes `basis_exercise_id: p.basisExerciseId` through to the insert payload.

### 4.5 Tests

- `test/workouts/set_resolver_test.dart`: add cases for `basisExerciseId` present vs. absent (this is really testing the call-site logic, so it may make more sense as a small pure function extracted alongside the resolver, e.g. `String resolveBasisExerciseId(WorkoutSet set, WorkoutExercise exercise) => set.basisExerciseId ?? exercise.exerciseId;` — extracting it makes it unit-testable without a widget harness).
- `test/workouts/set_editor_test.dart`: cover the new "Based on" control appearing/defaulting correctly and flowing through to `onAddPercentageSets`.
- `test/workouts/models_test.dart`: `WorkoutSet.fromJson` with and without a `basis_exercise_id`/nested `exercises` join.

---

## 5. Phase 2 — Exercise catalog gap

Before programs can be authored faithfully, the predefined exercise list needs to grow. Cross-referencing `supabase/seed.sql` against the four transcribed programs, these appear repeatedly across the source material but don't exist as predefined exercises today:

**Missing barbell/classic-lift variants:** Split Jerk, Push Press, Strict Press (distinct from "Overhead Press"? confirm — Strict Press and Overhead Press are usually synonyms; if so this is a naming decision, not a gap), Snatch Pull, Clean Pull, Snatch Deadlift, Clean Deadlift, Block Snatch, Block Clean, Block Clean and Jerk, Block Power Clean, Overhead Squat, Snatch Balance, Muscle Snatch, Hang Power Clean, Hang Power Snatch, Snatch Grip Push Press, Power Clean + Push Press (complex — see note below), Tall Clean, No Hook/No Contact/No Foot Snatch variants (probably just "Snatch" with a technique note, not separate exercises — see 5.1).

**Missing accessory/assistance work:** Pull-up, Pull-down, Bicep Curl, Lateral Raise, Skull Crusher, French Press, Arnold Press, Strict Press, Bench Press variants (DB Bench Press already covered by "Bench Press"? confirm unit), Kettlebell Swing, Box Jump, Broad Jump, Depth Jump, Squat Jump, Skater Hop, Single Leg Squat, Back Extension, GHD Sit-Up, Hanging Leg Raise, Side Plank/Plank, Russian Twist, Banded Walk/TKE, Sled Push, Farmer/Suitcase/Overhead Carry, Sprints.

### 5.1 A modeling decision this surfaces: tempo/pause/eccentric variants

The source programs constantly prefix a lift with a technique modifier — "Pause Front Squat," "Tempo Snatch Deadlift," "Eccentric Bicep Curl," "No Hook No Foot Snatch," "3 Second Pause Split Jerk." Two ways to handle this, and the plan needs a decision before seeding:

- **(A) Separate exercise rows** ("Pause Front Squat" as its own predefined exercise, distinct from "Front Squat"). Simple, matches the source text exactly, but multiplies the exercise table significantly and — critically — **fragments 1RM/PB tracking**: a percentage set on "Pause Front Squat" would need its own PB history or (more likely) would want to use `basis_exercise_id` to point at plain "Front Squat" anyway. If we go this route, the basis-exercise feature from Phase 1 is doing double duty as the fix for this too.
- **(B) A single exercise ("Front Squat") plus a free-text tempo/technique note on the `program_exercise` / `workout_exercise` row** (the `notes` field already exists on both). The percentage always resolves against the base lift's real max. This keeps the exercise catalog clean and makes `basis_exercise_id` unnecessary for this specific case (the tempo variant *is* the same lift, full stop — no cross-lift percentage involved).

**Decided: (B).** It's less catalog bloat, keeps PB tracking coherent, and matches how a real athlete would log it (they'd log it against "Front Squat" 1RM, with a note that it was paused). `basis_exercise_id` is reserved for genuine cross-lift cases like "Front Squat @ 85% of Clean & Jerk," not for technique variants of the same lift.

Practical effect on the seed list and on transcribing the research docs into real program data later:
- "Pause Front Squat," "Tempo Front Squat," "4 Second Eccentric Front Squat," "Pause at Half Front Squat" → all log against the single predefined **Front Squat** exercise, with the tempo/technique cue captured in the `program_exercise.notes` / `workout_exercise.notes` field (e.g. "2s eccentric, 5s pause, ATG").
- Same pattern for every other modifier seen in the research docs: "No Hook No Foot Snatch," "No Contact Clean," "Touch and Go Split Jerks," "Eccentric Bicep Curl," etc. — the modifier is a note on the base lift, not a new exercise row.
- Genuine distinct movements still get their own exercise row even though they look like variants — e.g. **Hang Power Clean** and **Power Clean** are different enough lifts (different starting position/mechanics, and lifters track separate maxes for them) to stay separate, as do **Snatch** vs. **Power Snatch** vs. **Block Snatch**. The line: if a competent lifter would keep a separate PR for it, it's its own exercise; if it's the same lift performed with a tempo/pause/restriction cue, it's a note.
- This trims the Section 5 "missing exercises" list — drop the No-Hook/No-Contact/Touch-and-Go/Pause/Tempo/Eccentric-prefixed entries from the seed list entirely; only the underlying base lifts need adding.

### 5.2 Complex/combo lifts (e.g. "Power Clean + Push Press," "Snatch + Tempo Overhead Squat")

These appear throughout as single training-max-tested combos. They aren't a "basis exercise" case either — they're their own compound movement with their own session-established max, tested and used within the same session/week (self-referential, not tied to a stored PB at all in most cases — see Section 8.2). Treat each named complex as its own predefined exercise (e.g. "Power Clean + Push Press") when it's tested for a rep max and later percentaged off *itself* — this is exactly today's existing exercise model, no schema change needed, just more seed rows.

### 5.3 Action items

- Expand `supabase/seed.sql` with the missing exercises identified above (final list to be reconciled against decision in 5.1).
- Note in `supabase/seed.sql`'s header comment (already states predefined rows aren't tracked for production) that production's real exercise table will need the same additions applied manually, per existing process.

---

## 6. Phase 3 — Database schema for Programs

Five new tables, in creation order (matches FK dependency order — each `supabase migration new <slug>` should be its own migration per the repo's existing one-concern-per-migration style seen in `20260802213619_add_workout_visibility.sql` and `20260802224727_add_workouts_updated_at_trigger.sql`):

1. `supabase migration new create_programs_table`
2. `supabase migration new create_program_weeks_table`
3. `supabase migration new create_program_days_table`
4. `supabase migration new create_program_exercises_table`
5. `supabase migration new create_program_sets_table`
6. `supabase migration new create_program_instances_table`
7. `supabase migration new link_workouts_to_program_instances`
8. `supabase migration new add_basis_exercise_to_workout_sets` (this is Phase 1's migration — listed here too since it must land before program_sets exists if program_sets is defined to look structurally identical; ordering-wise it can actually go first, independently)

### 6.1 `programs`

**Soft delete:** per the Section 12.4 decision, there is no user-facing hard delete for a program — "Delete" in the UI sets `is_archived = true`, which is always allowed (no FK constraint blocks it) and reversible. A real `DELETE` is never issued by the app for a row that has instance history; `program_instances.program_id` uses `ON DELETE RESTRICT` (Section 6.6) as a database-level backstop against that ever happening, not as the primary mechanism — the primary mechanism is that the app just doesn't expose hard delete once a program has been started.

```sql
create table public.programs (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  name        text not null,
  description text,
  is_public   boolean not null default false,
  is_archived boolean not null default false,
  archived_at timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

alter table public.programs enable row level security;

create index idx_programs_user_id on public.programs (user_id);
create index idx_programs_active on public.programs (user_id, created_at desc) where is_archived = false;
create index idx_programs_public on public.programs (created_at desc) where is_public = true and is_archived = false;

create trigger set_programs_updated_at
  before update on public.programs
  for each row execute function public.set_updated_at();

create policy programs_select on public.programs
  for select to authenticated using ((select auth.uid()) = user_id);
create policy programs_select_public on public.programs
  for select to authenticated using (is_public = true);
create policy programs_insert on public.programs
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy programs_update on public.programs
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy programs_delete on public.programs
  for delete to authenticated using ((select auth.uid()) = user_id);
```

### 6.2 `program_weeks`

```sql
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

-- owner CRUD policies mirroring workout_exercises_{select,insert,update,delete}
-- (( select auth.uid() ) = user_id) for all four, UPDATE with USING + WITH CHECK

create policy program_weeks_select_public on public.program_weeks
  for select to authenticated using (exists (
    select 1 from public.programs p where p.id = program_weeks.program_id and p.is_public = true
  ));
```

### 6.3 `program_days`

```sql
create table public.program_days (
  id               uuid primary key default gen_random_uuid(),
  program_id       uuid not null references public.programs(id) on delete cascade, -- denormalized for direct ordering/query
  program_week_id  uuid not null references public.program_weeks(id) on delete cascade,
  user_id          uuid not null references auth.users(id) on delete cascade,
  day_number       integer not null, -- display-only grouping within the week (e.g. 1 = "Day 1"/"Monday"); NOT unique — see note
  title            text not null,    -- "Day 1", "Monday", "Athletic Power Day"
  is_rest_day      boolean not null default false,
  notes            text,
  position         integer not null, -- GLOBAL order across the whole program; drives materialization order
  created_at       timestamptz not null default now(),
  unique (program_id, position)
);

alter table public.program_days enable row level security;
create index idx_program_days_program_week_id on public.program_days (program_week_id);
-- owner + public-read policies, same shape as program_weeks
```

**Note on multiple sessions per calendar day:** `day_number` is intentionally *not* unique per week. Two `program_days` can share `day_number = 3` (e.g. an AM and PM session both labeled "Day 3") — each still gets its own `position` and becomes its own separate `workouts` row at materialization, landing on the same calendar date. This directly satisfies "one or more workouts a day" from the original ask without a separate session-grouping table.

### 6.4 `program_exercises`

Structurally identical to `workout_exercises`, minus nothing:

```sql
create table public.program_exercises (
  id              uuid primary key default gen_random_uuid(),
  program_day_id  uuid not null references public.program_days(id) on delete cascade,
  user_id         uuid not null references auth.users(id) on delete cascade,
  exercise_id     uuid not null references public.exercises(id),
  position        integer not null,
  notes           text,
  created_at      timestamptz not null default now()
);

alter table public.program_exercises enable row level security;
create index idx_program_exercises_program_day_id on public.program_exercises (program_day_id);
-- owner + public-read policies, same shape as workout_exercises_select_public
```

### 6.5 `program_sets`

Structurally identical to `workout_sets` minus the logging-only columns (`completed`, `actual_weight_kg`, `actual_reps`), plus `basis_exercise_id` from day one:

```sql
create table public.program_sets (
  id                    uuid primary key default gen_random_uuid(),
  program_exercise_id   uuid not null references public.program_exercises(id) on delete cascade,
  user_id               uuid not null references auth.users(id) on delete cascade,
  position              integer not null,
  target_reps           integer,
  weight_mode           text not null check (weight_mode in ('percentage','absolute')),
  percentage            numeric,
  absolute_weight_kg    numeric,
  basis_exercise_id     uuid references public.exercises(id) on delete set null,
  note                  text,
  created_at            timestamptz not null default now(),
  constraint program_sets_weight_mode_value check (
    (weight_mode = 'percentage' and percentage is not null)
    or (weight_mode = 'absolute' and absolute_weight_kg is not null)
  )
);

alter table public.program_sets enable row level security;
create index idx_program_sets_program_exercise_id on public.program_sets (program_exercise_id);
-- owner + public-read policies, same shape as workout_sets_select_public

-- and the exercises-visibility extension (same pattern as Section 4.1) for
-- both exercise_id-on-program_exercises and basis_exercise_id-on-program_sets
-- when the owning program is public.
```

### 6.6 `program_instances`

```sql
create table public.program_instances (
  id           uuid primary key default gen_random_uuid(),
  program_id   uuid not null references public.programs(id) on delete restrict, -- backstop for the Section 12.4 soft-delete decision; the app itself never hard-deletes a program with instance history
  user_id      uuid not null references auth.users(id) on delete cascade,
  started_at   date not null default current_date,
  status       text not null default 'active' check (status in ('active','completed','abandoned')),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

alter table public.program_instances enable row level security;
create index idx_program_instances_user_id on public.program_instances (user_id);

create trigger set_program_instances_updated_at
  before update on public.program_instances
  for each row execute function public.set_updated_at();

-- standard owner-only CRUD policies (auth.uid() = user_id); instances are
-- never public even if the source program is.
```

### 6.7 Link `workouts` back to the program that generated them

```sql
alter table public.workouts
  add column program_instance_id uuid references public.program_instances(id) on delete set null,
  add column program_day_id      uuid references public.program_days(id) on delete set null;

create index idx_workouts_program_instance_id on public.workouts (program_instance_id);
```

`on delete set null` on both: deleting an instance or the source program shouldn't delete the user's actual logged history, just orphan the back-reference.

### 6.8 `supabase db lint` checklist (per CLAUDE.md, this runs in CI)

Every table above needs: RLS enabled ✓, ownership policies scoped `TO authenticated USING ((select auth.uid()) = user_id)` ✓, UPDATE policies declaring both `USING` and `WITH CHECK` ✓. Run `supabase db reset && supabase db lint` locally before handing off / opening the PR.

---

## 7. Phase 4 — Dart models

New module: `lib/features/programs/models/`

- `program.dart` — `Program { id, userId, name, description, isPublic, updatedAt, weeks }`, `fromJson` unpacks nested `program_weeks(*, program_days(*, program_exercises(*, exercises(name), program_sets(*, exercises(name)))))`, sorted by `position` at every level (mirrors how `Workout.fromJson` sorts `exercises` by `position`, and `WorkoutExercise.fromJson` sorts `sets` by `position`).
- `program_week.dart` — `ProgramWeek { id, programId, weekNumber, label, notes, position, days }`.
- `program_day.dart` — `ProgramDay { id, programWeekId, dayNumber, title, isRestDay, notes, position, exercises }`.
- `program_exercise.dart` — same shape as `WorkoutExercise` minus `workoutId`, plus `programDayId`.
- `program_set.dart` — same shape as `WorkoutSet` minus `completed`/`actualWeightKg`/`actualReps`, plus `basisExerciseId`/`basisExerciseName`.
- `program_instance.dart` — `ProgramInstance { id, programId, programName, userId, startedAt, status }` (`programName` populated via a nested `programs(name)` select for display, e.g. "Currently running: ZT 6 Week Program").

All hand-written `fromJson` factories, no freezed/json_serializable, per CLAUDE.md convention.

---

## 8. Phase 5 — Providers

New module: `lib/features/programs/providers/`

### 8.1 `programs_provider.dart`

`ProgramsNotifier` (`@Riverpod(keepAlive: true)`), same shape as `WorkoutsNotifier`: `ref.watch(authStateProvider)` first, fetch the current user's own, non-archived programs by default (`.eq('user_id', userId).eq('is_archived', false)`), `createProgram({name, description, isPublic}) -> id`.

No `deleteProgram` — per the Section 12.4 decision there's no hard delete exposed at all. Instead:
- `archiveProgram(id)` → `update({'is_archived': true, 'archived_at': DateTime.now().toIso8601String()})`.
- `restoreProgram(id)` → `update({'is_archived': false, 'archived_at': null})`.
- A second query/provider (or a parameterized `build(bool includeArchived)`) for the "Archived" view, `.eq('is_archived', true)`, so a user can find and restore something they archived.

### 8.2 `program_detail_provider.dart`

`ProgramDetailNotifier(programId)` (`@Riverpod(keepAlive: true)`) — the builder. Mirrors `WorkoutDetailNotifier` method-for-method, one level deeper:

- `addWeek({label, notes})` → inserts into `program_weeks` at `nextWeekNumber`/`nextPosition`.
- `addDay(weekId, {title, isRestDay})` → inserts into `program_days`, computing global `position` as `current.days.length` across the whole program (not just the week) plus a helper `dayNumber` default.
- `addExercise(dayId, exerciseId)` → same shape as `WorkoutDetailNotifier.addExercise`.
- `addPercentageSets(programExerciseId, List<ParsedProgramSet> parsed)` / `addAbsoluteSets(...)` → same shape as today's, `ParsedProgramSet` carrying the same 3 fields as the updated `ParsedSet` (reps, percentage, basisExerciseId).
- `removeExercise`, `updateExerciseNotes`, `deleteSet`, `reorderDay`/`reorderWeek` (new — programs need drag-to-reorder since, unlike a single workout, the whole point is planning a sequence; recommend a simple `updatePosition(id, newPosition)` bulk-renumbering helper reused by weeks/days/exercises/sets).
- `updateProgramMeta({name, description})`, `updateVisibility(isPublic)`.
- Every mutation ends with `ref.invalidateSelf(); await future;`, per the established convention.

### 8.3 `program_instances_provider.dart` — the "Start Program" flow

This is the one genuinely new kind of operation in the whole feature: a bulk, multi-table, order-dependent write. Two implementation options:

**A precedent already exists for this shape of operation.** `WorkoutsNotifier.duplicateWorkout()` (`lib/features/workouts/providers/workouts_provider.dart`) already deep-copies one workout — fetch the nested tree, insert a new `workouts` row, then loop its exercises doing one `workout_exercises` insert + one `workout_sets` batch-insert per exercise, sequentially, entirely client-side. No RPC, no transaction. This is real, shipped precedent for "Option A" below, at the scale of one workout (a handful of exercises, ~10-20 sequential round trips total).

**Option A — client-side loop (matches existing "notifier talks to Supabase directly" convention most literally, and matches `duplicateWorkout`'s precedent exactly).**
`startProgram(programId, startDate)`:
1. Fetch the full program tree (already-shaped by `ProgramDetailNotifier.build`, or a fresh fetch).
2. Insert one `program_instances` row, get its id.
3. Walk `program.weeks -> days` in `position` order, computing each day's date as `startDate.add(Duration(days: index))` (index = day's global position, 0-based).
4. Bulk-insert all `workouts` rows in one `.insert([...]).select('id')` call (title = the day's `title`, date as computed, `program_instance_id`, `program_day_id`), capturing returned ids in day-index order. **Every `program_day` gets a row here, including empty rest days** (decided in Section 12.3) — a rest day simply ends up with zero `workout_exercises` after step 5, same as if a user manually created a blank workout and never added anything to it.
5. Bulk-insert all `workout_exercises` referencing the new workout ids, capturing returned ids.
6. Bulk-insert all `workout_sets` referencing the new workout_exercise ids (carrying `basis_exercise_id` straight through).
7. `ref.invalidate(workoutsProvider)` so the freshly materialized workouts show up.

Simple, fits the codebase's existing convention exactly (not just in spirit — `duplicateWorkout` is the same pattern at smaller scale), but the round-trip count scales with program size in a way `duplicateWorkout` never has to deal with: `duplicateWorkout` copies one workout (a handful of exercises → maybe 10-20 sequential round trips, done per-exercise in a loop, each awaited before the next). An 8-week/6-day program is ~48 workouts, ~150–250 workout_exercises, ~700–1200 workout_sets — following `duplicateWorkout`'s exact per-exercise-sequential style would mean hundreds of *sequential, awaited* round trips (not the bulk-insert-per-table version sketched above, which would need to be a genuinely new pattern, not a reuse of the existing one). Either way — hundreds of sequential calls, or a handful of large bulk-insert calls — there's no transactional safety: a dropped connection partway through leaves the user with a half-materialized program and no clean recovery path (there's no "resume" or "rollback" concept for a partially-started program in this plan).

**Option B — a Postgres RPC function, called via `.rpc()` (recommended).**
Write a `start_program(p_program_id uuid, p_start_date date) returns uuid` `plpgsql` function (its own migration: `supabase migration new create_start_program_function`) that does the whole walk server-side inside one transaction and returns the new `program_instances.id`. The Dart side becomes a single call:

```dart
final instanceId = await _db.rpc('start_program', params: {
  'p_program_id': programId,
  'p_start_date': startDate.toIso8601String().substring(0, 10),
});
```

This is still "the notifier talks to Supabase directly" (an RPC call is not a repository layer, it's just a different Supabase entry point than `.from()`), it's atomic, and it's one round trip instead of hundreds. The function still needs `security invoker` (not `security definer`) so RLS continues to gate it by the calling user — the existing `handle_new_user()`/`set_updated_at()` functions in the schema use `security definer` for admin-ish trigger work, which is not the right model here since this function is doing normal user-scoped writes.

**Decided: Option B (RPC).** `start_program` ships as a `security invoker` Postgres function, called via `.rpc()`, doing the whole materialization server-side in one transaction. Chosen over Option A on correctness/performance grounds — an 8-week program is large enough (~48 workouts, hundreds of exercises/sets) that hundreds of sequential client round trips would make "Start Program" a genuinely slow, fragile button with no rollback on partial failure, and that outweighs the consistency argument for matching `duplicateWorkout`'s existing client-side style. This is the first piece of server-side procedural (plpgsql) logic in the app beyond the existing trigger functions (`handle_new_user`, `set_updated_at`) — worth calling out in the PR description when this ships, since it's a small precedent-setting choice for how future bulk operations get built.

- `activeProgramInstanceProvider` (stretch, Section 10) — surfaces "you're currently running X" for the dashboard.
- `completeProgramInstance(id)` / `abandonProgramInstance(id)` → simple status updates.

---

## 9. Phase 6 — Routing & screens

### 9.1 Routing (`lib/core/constants/app_constants.dart`)

```dart
static const String routePrograms = '/shell/programs';
static const String routeProgramNew = '/programs/new';
static String routeProgramDetail(String id) => '/programs/$id';
static String routeProgramEdit(String id) => '/programs/$id/edit';
```

Mirrors the existing `routeWorkouts` / `routeWorkoutNew` / `routeWorkoutDetail` / `routeWorkoutEdit` group exactly.

### 9.2 Where "Programs" lives in the shell — **decided: 5th tab**

The shell currently has 4 `StatefulShellBranch`es: Home, PRs, Workouts, Community. **Decision: add Programs as a 5th tab** (`routePrograms` as its own `StatefulShellBranch`), not nested inside Workouts. Revisit later if it turns out to overcrowd the nav — nothing here is structurally hard to undo (moving a route from a top-level branch into a nested tab later is a small, contained change).

Implementation notes, confirmed against the current `lib/features/shell/app_shell.dart` (not a separate `responsive_layout.dart` file — `AppShell` itself branches on `MediaQuery.sizeOf(context).width < AppConstants.kMobileBreakpoint`):

- Add a 5th `StatefulShellBranch` for `routePrograms` in `lib/app.dart`'s route list, pointing at `ProgramsScreen`. It becomes branch index **4** (today: 0 = Home, 1 = PRs, 2 = Workouts, 3 = Community).
- `AppShell` hardcodes its destinations as two parallel manual lists keyed by `shell.currentIndex` / `shell.goBranch(i)` — there's no loop over a route config, so a 5th tab means adding a 5th `IconButton` (mobile) and a 5th `NavigationRailDestination` (desktop) by hand, matching the existing selected/unselected icon-pair pattern (e.g. `Icons.checklist_outlined` / `Icons.checklist` or similar for Programs — pick something visually distinct from the existing home/list/fitness_center/public icons).
- **Concrete thing to check, not just "room in general":** the mobile `BottomAppBar`'s `Row` today is `[Home icon, SizedBox(width: 48) — manual FAB spacer, PRs icon, Workouts icon, Community icon]` under `mainAxisAlignment: MainAxisAlignment.spaceAround`. Adding a 5th icon makes it 5 icons + 1 fixed-width spacer competing for space on a `spaceAround` row — on the narrowest supported phones this may crowd or misalign the FAB-clearing gap. Worth an actual visual check on a small device/simulator once built; if it's tight, consider moving the manual spacer to sit visually centered regardless of icon count rather than resizing icons.
- The shell's central "+" FAB (`_showAddMenu`, both the mobile `FloatingActionButton` and the desktop rail's mini FAB) currently opens a bottom sheet with two options: "New Personal Best" and "New Workout." **Add a third: "New Program"** → `context.push(AppConstants.routeProgramNew)`, for discoverability parity with the other two creatable things.
- Any FAB on `ProgramsScreen` still needs its own explicit `heroTag` per the existing shell-wide rule (`test/workouts/fab_hero_tag_test.dart`) — see Section 9.3 for the specific tag/style to use.

### 9.3 Screens (`lib/features/programs/screens/`)

- `programs_screen.dart` — list of the user's non-archived programs, confirmed against the existing `workouts_screen.dart` as the pattern to mirror exactly:
  - `FloatingActionButton.extended(heroTag: 'programsNewFab', icon: Icons.add, label: 'New program')`, same shape as `WorkoutsScreen`'s `'workoutsNewFab'` (**must set an explicit `heroTag`** — `test/workouts/fab_hero_tag_test.dart` exists specifically to guard this rule; extend that test file, or add a sibling, with the same `expect(fab.heroTag, 'programsNewFab')` shape).
  - Each row's trailing `PopupMenuButton<String>` mirrors `WorkoutsScreen`'s exactly (`edit` / `duplicate` / `delete` today) — for programs the equivalent list is `edit` / `duplicate` (F4, deferred — omit for now) / **`archive`** in place of `delete` (per the 12.4 decision, there is no `delete` action at all). A separate "Archived" filter/section (e.g. a second tab or a toggle in the app bar) surfaces archived programs with a **Restore** action in the same menu style.
  - Reuse `core/utils/date_formatter.dart`'s `formatDate()` for any date shown (e.g. a program's `created_at`, or an instance's `started_at`) — same utility `WorkoutsScreen` already uses for workout dates, don't introduce a second date-formatting path.
- `new_program_screen.dart` — name/description/public toggle, mirrors `new_workout_screen.dart` exactly (nothing written until Save, matching the existing "no trace on back-out" comment/behavior).
- `program_edit_screen.dart` — the builder. This is the largest new UI surface in the whole feature: nested week → day → exercise → set editing. Recommend an expandable/accordion list of weeks, each expandable into days, each day rendering a reworked set editor (Section 9.4).
- `program_detail_screen.dart` — read-only rollup view (mirrors `WorkoutDetailScreen`'s read affordances) plus the primary **"Start Program"** call to action, which opens a small dialog to confirm/adjust the start date before calling `ProgramInstancesNotifier.startProgram`.

### 9.4 Reusing `SetEditor`

`SetEditor` today is hard-typed to `WorkoutExercise`/`WorkoutSet` and calls back with raw `(sets, reps, weightKg)` / `List<ParsedSet>`. `program_edit_screen.dart` needs the same dialogs (`_showPercentageSetDialog`, `_showAbsoluteSetDialog`, the `_NumberField` stepper, the basis-exercise picker from Phase 1) against `ProgramExercise`/`ProgramSet` instead. Rather than duplicate ~300 lines, recommend extracting the presentation-only pieces (`_NumberField`, the two dialogs, `_SetRow`) to operate on a small shared DTO instead of the concrete model:

```dart
class EditableSetRow {
  final String id;
  final int? targetReps;
  final String weightMode;
  final double? percentage;
  final double? absoluteWeightKg;
  final String? basisExerciseId;
  final String? basisExerciseName;
  // no completed/actual fields — those stay workout-only
}
```

Both `WorkoutSet` and `ProgramSet` map to `EditableSetRow` for display; the two callback types (`onAddPercentageSets`, `onAddAbsoluteSets`, `onDeleteSet`) stay as generic function parameters as they are today. This turns `SetEditor` into something usable from both `edit_workout_screen.dart` and `program_edit_screen.dart` unchanged. This refactor should land as part of Phase 1 (basis exercise) or immediately before Phase 6, since Phase 1 is already touching this widget for the "Based on" control.

---

## 10. Phase 7 — Dashboard / "current program" surfacing (stretch, not required for the core gap)

Nice-to-have once the above ships: a dashboard card showing the active `program_instances` row (if any) with something like "Week 3 of 6 — next up: Thursday". This is pure read/derive from `workouts.program_instance_id` + `date` — no new writes. Deferred out of this plan's required scope; tracked as F5 in `docs/research/program-future-considerations.md` so it isn't forgotten.

---

## 11. Testing strategy

Following the existing per-feature test layout (`test/workouts/*`):

- `test/programs/models_test.dart` — `Program`/`ProgramWeek`/`ProgramDay`/`ProgramExercise`/`ProgramSet.fromJson`, including nested unpacking and position-sorting at every level (mirrors `test/workouts/models_test.dart`).
- `test/programs/program_detail_provider_test.dart` (widget-level, via the subclass-and-override pattern) — builder mutations against a stubbed notifier.
- `test/programs/program_edit_screen_test.dart` — widget-level, `programDetailProvider.overrideWith(() => _FixtureProgramDetailNotifier())`, matching how `edit_workout_screen` tests stub `workoutDetailProvider`.
- `test/programs/fab_hero_tag_test.dart` (or extend the existing one) — guard the new FABs.
- Pure-logic unit tests, no widget harness needed:
  - The day → date materialization function (extract it as a standalone pure function, e.g. `DateTime programDayDate(DateTime startDate, int position) => startDate.add(Duration(days: position));`, so it's testable without touching Supabase or the RPC).
  - The basis-exercise resolution helper from Section 4.3 (`resolveBasisExerciseId`).
- `supabase db reset && supabase db lint` must stay green — part of `.github/workflows/pr-checks.yml`'s existing CI job, no workflow changes needed, just schema correctness.

---

## 12. Open questions to resolve before Claude Code starts building

1. ~~**IA placement (9.2):** 5th shell tab for Programs, or nested under Workouts?~~ **Decided: 5th shell tab.** See 9.2 for the `AppShell`/`responsive_layout.dart` implementation notes.
2. ~~**Tempo/pause/eccentric lift variants (5.1):** separate exercise rows vs. a note on the exercise + always resolving against the base lift.~~ **Decided: note-based** — modifiers (pause, tempo, eccentric, no-hook, no-contact, touch-and-go, etc.) are captured as a note on the base lift, not as separate exercise rows. See 5.1 for the seed-list impact and the dividing line between "note" and "genuinely separate lift."
3. ~~**Rest days at materialization:** should a fully empty rest day still materialize an empty `workouts` row, or be skipped entirely?~~ **Decided: materialize it (Option A).** Every `program_day`, including empty rest days, gets a real `workouts` row at `startDate + position days`, even with zero exercises. Keeps the date math trivial (`position` always equals "days since start," no gap-tracking needed). See Section 8.3 for the impact.
4. ~~**`program_instances.program_id` delete behavior:**~~ **Decided: `ON DELETE RESTRICT` + soft delete.** A program template can never be hard-deleted while any instance (active, completed, or abandoned) still references it. "Deleting" a program from the UI is actually an archive (`is_archived = true`), which is always allowed regardless of instance history and is reversible ("recover"/"restore"). See Section 6.1 and 8.1 for the schema/provider impact.
5. ~~**Editing a program after it's been started:**~~ **Decided: Option A — no propagation.** Since materialization copies data at start time, already-materialized workouts are permanently insulated from later template edits; editing a program only affects future "Start" runs. No warning, versioning, or diff/propagate system is built for this pass. The propagate-to-active-instances idea (Option B) is captured as a future consideration — see `docs/research/program-future-considerations.md`.
6. ~~**Scope of "basis exercise" picker:**~~ **Decided: unrestricted.** Any exercise in the catalog can be picked as the basis for any other exercise's percentage sets, no filtering to "exercises already in this program" or similar. This isn't just a simplicity shortcut — it's a real, common programming pattern (e.g. "Front Squat @ 60% of Back Squat max for 5"), so restricting the picker would actively block legitimate programming, not just prevent edge-case misuse. No new validation logic beyond what already exists: if the chosen basis exercise has no recorded PB, `resolveSetWeightKg()` already returns `null` and the UI already has to handle that (per CLAUDE.md's existing rule that percentage sets with no 1RM must not default to zero) — same path as today's behavior for any percentage set on a lift with no logged max.
7. ~~**RPE-based sets and "% of last logged session" sets:**~~ **Decided: defer, out of scope for this pass.** Both appear repeatedly in the research docs (e.g. `ZT 6 Week Program` Week 5 Monday: "Front Squat: build to RPE 8") but are a materially different `weight_mode` from today's `percentage`/`absolute` (RPE isn't resolvable to a weight without the lifter's own perceived-exertion input at the time; "last session" requires referencing a previous logged set, not a stored PB at all) and need their own design pass rather than growing `weight_mode` now. Tracked as F2 in `docs/research/program-future-considerations.md`.
8. ~~**Community/sharing parity for programs:**~~ **Decided: defer, out of scope for this pass.** The schema in Section 6 includes `is_public` and matching RLS from day one (cheap to include now and left in), but the Community-tab browsing experience for public programs (mirroring `community_workouts_provider.dart`) is not built in this pass — ship programs privately first, add community browsing as a fast-follow once the core authoring/starting flow is validated. Tracked as F3 in `docs/research/program-future-considerations.md`.
9. ~~**Program versioning / duplication:**~~ **Decided: defer, out of scope for this pass.** No "fork a public program" or "duplicate my own program" flow is built here. Likely wanted eventually (e.g. take "ZT 6 Week Program" and tweak weights) but not required for the core gap this plan addresses. Tracked as F4 in `docs/research/program-future-considerations.md`.

---

## 13. Suggested build order

1. Phase 1 (basis exercise) + the `SetEditor` → `EditableSetRow` refactor (Section 9.4) together, since Phase 1 already needs to touch `SetEditor`. Ship and test independently of everything else.
2. Phase 2 exercise catalog additions (seed.sql), pending the 5.1 decision.
3. Phase 3 schema (all 6 new tables + the `workouts` linkage columns), in the migration order listed in Section 6.
4. Phase 4 models + Phase 5 providers (`ProgramsNotifier`, `ProgramDetailNotifier`) — enough to author a program end-to-end, no Start yet.
5. Phase 6 screens for authoring (`programs_screen`, `new_program_screen`, `program_edit_screen`, `program_detail_screen` without the Start CTA wired up).
6. `start_program` RPC (Option B, Section 8.3) + `ProgramInstancesNotifier` + wiring the Start CTA into `program_detail_screen`.
7. Test pass (Section 11) + `supabase db lint` + update `CLAUDE.md`'s Architecture/Domain rules/Database sections to document the new Program concept, the new tables, and the basis-exercise behavior (this file currently has no mention of programs at all).
8. Re-transcribe the 4 ZT programs from `docs/research/*.md` into real program data (manually, or via a one-off seed script) as an end-to-end validation that the schema actually captures everything the research docs flagged — this is the real acceptance test for the whole feature.
