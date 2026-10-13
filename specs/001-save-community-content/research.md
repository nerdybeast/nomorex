# Research: Save and Start Community Workouts and Programs

All Technical Context unknowns are resolved below. Each entry: **Decision / Rationale /
Alternatives considered.**

## R1. Where the copy happens: server-side RPC, not a client loop

**Decision**: Two new `plpgsql` functions, `copy_workout(p_source_workout_id, p_start)` and
`copy_program(p_source_program_id, p_start_date)`, both `SECURITY INVOKER`, each doing the full
copy (and optional start) in one transaction.

**Rationale**:
- FR-011/FR-016 require all-or-nothing. A client-side loop (like `duplicateWorkout()` +
  `copyWorkoutContents()`) has no rollback — a failure mid-copy leaves a half-built workout.
- SC-003 (12-week × 6-day program in < 5 s): ~72 days × ~5 exercises × ~4 sets ≈ 1,800 rows.
  Sequential client round trips can't hit that on mobile; a single RPC can.
- Direct precedent: `start_program` is an RPC for exactly these two reasons
  (`20260805020858_create_start_program_function.sql` header).
- `SECURITY INVOKER` keeps the read of the source gated by existing RLS (the viewer can only
  read public rows) and the writes gated by ownership policies — Constitution I.

**Alternatives considered**:
- *Client-side copy reusing `copyWorkoutContents`*: rejected — no atomicity, too slow for programs.
- *`SECURITY DEFINER`*: rejected — not needed (public rows are already readable by the invoker)
  and would bypass RLS, which Constitution I forbids without written justification.

## R2. Starting a community program reuses `start_program`

**Decision**: `copy_program(..., p_start_date)` copies the template, then — when
`p_start_date` is non-null — calls `public.start_program(v_new_program_id, p_start_date)` inside
the same transaction and returns both ids.

**Rationale**: `start_program` only accepts programs the caller owns. After the copy, the caller
*does* own the new program, so the existing function works unchanged and scheduling behavior
is identical to starting one's own program (FR-015, FR-017). One transaction covers both steps
(FR-016).

**Alternatives considered**: relaxing `start_program`'s ownership check to accept public
programs — rejected; that is the "start without saving" mode the user ruled out (Clarification 1)
and would tie a run to a template the author can change or remove.

## R3. Starting a community workout

**Decision**: `copy_workout(..., p_start => true)` copies, then calls
`public.start_workout_session(v_new_workout_id)` in the same transaction. The client then
navigates to the copy's `WorkoutDetailScreen`.

**Rationale**: reuses the existing session state machine (`not_started → in_progress`) and the
`idx_workouts_one_active_per_group` guard; the new copy has a fresh `workout_group_id`, so it
can't collide with another active session.

## R4. Exercise mapping (FR-007, Constitution II)

**Decision**: inside the RPC, each source exercise (and each set's `basis_exercise_id`) maps to
an exercise in the viewer's catalog by `lower(trim(name))`:
1. If the source exercise is predefined → reuse its id unchanged.
2. Else, pick the viewer's matching exercise among
   `is_predefined = true OR user_id = auth.uid()`, ordered `is_predefined desc, created_at asc`
   (deterministic: a predefined lift wins, then the oldest custom one).
3. Else insert a custom exercise for the viewer with the source's (trimmed) name.
A per-call temp map (`source_exercise_id → viewer_exercise_id`) ensures each source exercise is
resolved/created once per copy (SC-006).

**Rationale**: Constitution II — across users, match by name. `oneRepMaxByNameProvider` folds
all of a viewer's same-named PRs under one lowercased key, so whichever same-named row the copy
picks, `lookupOneRepMax()` resolves it (id hit, or name fallback). Name matching therefore
agrees with 1RM resolution regardless of tie-break; the tie-break only needs to be
deterministic.

**Alternatives considered**: calling `ExercisesNotifier.ensureExerciseByName()` from the client
before the RPC — rejected; breaks atomicity and adds round trips per exercise. The SQL rule
mirrors its behavior (case-insensitive, trimmed, find-or-create).

**Follow-up**: `exercisesProvider` must be invalidated after a copy, since new custom exercises
may have been created.

## R5. Copy attribution: snapshot columns + an `is_copy` flag

**Decision**: add to both `workouts` and `programs`:
`is_copy boolean not null default false`, `copied_from_user_id uuid null` (FK `auth.users` — not `profiles`, see data-model.md —
`on delete set null`), `copied_from_display_name text null` (snapshot), and
`copied_from_workout_id` / `copied_from_program_id` (self-FK, `on delete set null`).

**Rationale**:
- The author's name must outlive the author's public content. `profiles_select` only exposes a
  profile to viewers who can currently see something that user published
  (`20260816223137_add_profile_display_name.sql`), so a live join would go dark the moment the
  author unpublishes — hence a snapshot taken at copy time, when the source is still readable.
- `is_copy` is needed independently of the FKs: once both FKs are nulled by deletion the row
  must *still* be a copy (unshareable, neutral label). FKs alone can't express that.
- `copied_from_*_id` powers FR-013 ("you already have a copy") with a simple indexed lookup.

**Display rule** (FR-010): label = `Copied from <ownerDisplayName(copied_from_display_name)>`,
falling back to `Copied from another user` when `copied_from_user_id` **or** the source id is
null (author or original removed), exactly as the spec states. A workout's source id is
`copied_from_workout_id ?? copied_from_program_id`: workouts generated from a copied program carry
the program's `copied_from_program_id`, otherwise they'd have no source id and always show the
fallback.

**Alternatives considered**: a separate `content_copies` link table — rejected; one-to-one with
the copy row, adds a join to every list, and Constitution III prefers the simpler shape.

## R6. Enforcing "copies can't be public" (FR-008, FR-019)

**Decision**:
- `CHECK (not (is_copy and is_public))` on `workouts` and `programs`.
- A `BEFORE UPDATE` trigger on both tables rejecting `is_copy` changing from `true` to `false`.
- UI disables the Public switch on copies with an explanatory subtitle.

**Rationale**: ownership RLS lets a user update any column on their own rows, so without the
trigger a client could clear `is_copy` and then publish. The trigger guards only `is_copy`
(not the `copied_from_*` FKs), so `on delete set null` cascades still work.

**Alternatives considered**: column-level `REVOKE UPDATE` — rejected; Supabase grants table-wide
privileges to `authenticated` and column privileges are easy to silently undo in later
migrations.

## R7. Inheritance of copy status (FR-008a)

**Decision**: every path that creates a workout/program *from* one of the user's own rows carries
the four attribution columns forward:
- `start_program` — replaced (`create or replace`) to stamp each materialized workout with the
  program's attribution columns, including `copied_from_program_id`.
- Client paths `WorkoutsNotifier.duplicateWorkout()`, `WorkoutDetailNotifier.finishWorkout()`'s
  next-instance insert, and `repeatWorkout()`'s fallback insert — use a shared helper that
  returns the attribution map from the source `Workout`.

**Rationale**: these are the only creation-from-existing paths today (`grep` for
`from('workouts').insert`). Inheritance is a UX/attribution rule, not a security boundary — a
user could always retype a program by hand — so client-side carry-forward is sufficient; the
server-side guarantee that matters (copies can't be public) is R6.

## R8. Guarding the source in the RPC (FR-018, FR-019, edge cases)

**Decision**: the RPC raises distinct errors before writing anything:
- not authenticated;
- source not found or not readable (covers private/deleted — RLS hides it);
- source owned by the caller (`own_content`);
- program archived (`archived`) — the `programs_select` policy does **not** filter archived rows,
  so the check must be explicit;
- source is itself a copy — unreachable in practice (copies can't be public) but asserted.

Error codes are documented in `contracts/rpc.md`; the client maps them to user-facing messages.

## R9. Testing approach

**Decision**:
- **SQL**: no pgTAP harness exists (`supabase/tests/` is empty, CI runs only `db reset` + `db lint`).
  RPC behavior is covered by the E2E suite against real Supabase, plus `db lint` for the new
  functions. Adding pgTAP is out of scope.
- **Unit**: model `fromJson` for the new columns; attribution-label helper (all fallback cases).
- **Widget**: community workout/program detail — buttons shown for others' content, hidden for
  own, "already saved" hint; copy badge on list cards and detail screens; Public switch disabled
  on copies. Notifiers stubbed via `overrideWith`, per Constitution IV.
- **E2E**: seed a public workout + public program owned by `b@b.com`; as `a@a.com`, save the
  workout, start it, and start the program — asserting presence, not counts.

## R10. Cache invalidation after a copy

**Decision**: after `copy_workout`: invalidate `workoutsProvider`, `exercisesProvider`, the
"existing copies" provider for that source, and (when started) `inProgressWorkoutsProvider`.
After `copy_program`: invalidate `programsProvider`, `exercisesProvider`, the existing-copies
provider, and (when started) `currentProgramInstancesProvider` (plus any instances-list
provider the dashboard watches).

**Rationale**: CLAUDE.md — mutations must invalidate every provider whose rendered output
changes; new custom exercises change the exercise picker.

## R11. Dates come from the client

**Decision**: `copy_workout` takes `p_today date` from the client instead of using `current_date`.

**Rationale**: `current_date` is the database's date (UTC). Every existing workout-creation path
uses the device's local date (`DateTime.now()`), and `start_program` already takes its date from
the client. Otherwise a copy saved in the evening in the Americas would be dated tomorrow.

## R12. Shipping order (Constitution V)

**Decision**: deliver in two PRs. PR 1 holds the migration and seed only. PR 2 holds the app code
and opens after PR 1's migration is applied to production.

**Rationale**: migrations and the web app deploy independently with no guaranteed order. If
the app lands first, Save/Start call RPCs that don't exist yet. PR 1 is purely additive, so
current app versions keep working.

## R13. Copy counts stay fresh

**Decision**: the copy-count providers count only the viewer's non-archived copies. Every
mutation that adds or removes a copy refreshes the whole family: save, `deleteWorkout`,
`archiveProgram`, `restoreProgram`.

**Rationale**: keepAlive providers otherwise keep showing "saved N times" after a copy is
deleted. CLAUDE.md names this as the codebase's usual stale-cache bug.
