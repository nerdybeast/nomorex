---

description: "Task list for Save and Start Community Workouts and Programs"
---

# Tasks: Save and Start Community Workouts and Programs

**Input**: Design documents from `specs/001-save-community-content/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/rpc.md, contracts/ui.md, quickstart.md

**Tests**: Included. Constitution IV requires unit tests for pure logic, widget tests (with
`overrideWith` notifier stubs, no network) for tap-driven behavior, and E2E through page objects.

**Organization**: Tasks are grouped by user story so each story can be implemented and tested on its own.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: The user story the task belongs to (US1–US4 from spec.md)

## Path Conventions

Flutter app in `lib/`, widget/unit tests in `test/`, E2E in `integration_test/`, schema in
`supabase/migrations/`. All SQL for this feature lives in **one** migration file created in T002
(referred to below as `MIGRATION`); later tasks append to it.

---

## Phase 1: Setup

**Purpose**: Branch and migration scaffold

- [X] T001 Create and switch to git branch `001-save-community-content` from up-to-date `main`
- [X] T002 Create the migration with `supabase migration new add_content_copies` (never hand-name it); record the generated path `supabase/migrations/<timestamp>_add_content_copies.sql` as `MIGRATION` and add a header comment summarizing the feature (copy columns, guards, copy RPCs)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Schema, models and shared display pieces that every story depends on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Schema (sequential: same file)

- [X] T003 In `MIGRATION`, add to `public.workouts`: `is_copy boolean not null default false`, `copied_from_user_id uuid null references public.profiles(id) on delete set null`, `copied_from_display_name text null`, `copied_from_workout_id uuid null references public.workouts(id) on delete set null`, `copied_from_program_id uuid null references public.programs(id) on delete set null` (set only on workouts generated from a copied program, so their label can name the author while the original exists); add index `(user_id, copied_from_workout_id) where copied_from_workout_id is not null` and plain indexes on `copied_from_user_id` and `copied_from_program_id`; add `constraint workouts_copy_not_public check (not (is_copy and is_public))`. (`programs` must exist before the FK — it does; this migration runs after `20260805013754…`)
- [X] T004 In `MIGRATION`, add to `public.programs`: `is_copy boolean not null default false`, `copied_from_user_id uuid null references public.profiles(id) on delete set null`, `copied_from_display_name text null`, `copied_from_program_id uuid null references public.programs(id) on delete set null`; add index `(user_id, copied_from_program_id) where copied_from_program_id is not null`; add `constraint programs_copy_not_public check (not (is_copy and is_public))`. Add indexes on both `copied_from_user_id` columns too, so `supabase db lint` doesn't flag unindexed foreign keys (see `20260813033503_add_missing_foreign_key_indexes.sql`)
- [X] T005 In `MIGRATION`, create trigger function `public.prevent_uncopy()` (`language plpgsql security invoker set search_path = public`) that raises `'copy_is_permanent: a copy cannot be un-marked'` when `old.is_copy and not new.is_copy`, and attach it `BEFORE UPDATE` on both `public.workouts` and `public.programs`. It must guard **only** `is_copy`, so the `on delete set null` cascades on the `copied_from_*` columns still succeed (research R6)
- [X] T006 In `MIGRATION`, create helper `public.map_exercise_for_viewer(p_source_exercise_id uuid) returns uuid` (`security invoker`, `set search_path = public`) implementing research R4: if the source is predefined, return its id; otherwise return the viewer's exercise matching `lower(trim(name))` among `is_predefined = true or user_id = auth.uid()`, ordered `is_predefined desc, created_at asc`, limit 1; otherwise insert a custom exercise (`name = trim(source.name)`, `is_predefined = false`, `user_id = auth.uid()`) and return its id. Returns null for a null input (used for nullable `basis_exercise_id`)
- [X] T007 Run `supabase db reset` (local only, never `--linked`) and `supabase db lint`; fix any errors in `MIGRATION`

### Seed data

- [X] T008 In `supabase/seed.sql`, add a **public** workout owned by `b@b.com`: at least one predefined exercise, one `b@b.com` custom exercise, one absolute-weight set and one percentage set with a `basis_exercise_id`, and notes on one exercise. Also add a **public, non-archived** program owned by `b@b.com` sized to the SC-003 target: **12 weeks × 6 days** (one of them a rest day each week), about 5 exercises per training day and about 4 sets per exercise, including at least one `b@b.com` custom exercise and one percentage set. Generate the weeks, days, exercises and sets with `generate_series` rather than writing every row out; use a fixed UUID for the program row so tests can find it. Re-run `supabase db reset` to confirm it loads

### Client models and shared display

- [X] T009 [P] Add `isCopy` (`bool`, default `false`, read from `is_copy`), `copiedFromUserId`, `copiedFromDisplayName`, `copiedFromWorkoutId` and `copiedFromProgramId` (all `String?`) to `Workout` in `lib/features/workouts/models/workout.dart`, with constructor and `fromJson` support
- [X] T010 [P] Add `isCopy`, `copiedFromUserId`, `copiedFromDisplayName` and `copiedFromProgramId` to `Program` in `lib/features/programs/models/program.dart`, in the same way as T009
- [X] T011 [P] Create `copyAttributionLabel({required bool isCopy, String? copiedFromUserId, String? copiedFromDisplayName, String? copiedFromSourceId})` in `lib/core/utils/copy_attribution.dart`. It returns null when `!isCopy`; `"Copied from another user"` when `copiedFromUserId` or `copiedFromSourceId` is null; otherwise `"Copied from ${ownerDisplayName(copiedFromDisplayName)}"` (reuse `lib/core/utils/owner_name.dart`). Callers pass `copiedFromSourceId: workout.copiedFromWorkoutId ?? workout.copiedFromProgramId` for workouts, and `program.copiedFromProgramId` for programs
- [X] T012 [P] Create `copyErrorMessage(Object error) → String` in `lib/core/utils/copy_errors.dart`, mapping the `<code>:` prefix of a `PostgrestException.message` per `contracts/rpc.md`: `not_authenticated` → "Sign in to save this."; `not_found`, `archived` and `source_is_copy` → "This is no longer available."; `copy_is_permanent` or Postgres code `23514` → "Copies of other people's content can't be shared."; anything else → "Couldn't save. Try again."
- [X] T013 Create the `CopiedFromBadge` widget in `lib/shared/widgets/copied_from_badge.dart`. It takes the same four inputs as T011 and renders the label with a small copy icon, using `Key('copied_from_badge')`. It renders `SizedBox.shrink()` when the label is null. Use theme text styles and no hardcoded colors (Constitution III)

### Foundational tests

- [X] T014 [P] Unit tests in `test/core/copy_attribution_test.dart` covering: not a copy → null; named author; null display name → "Copied from Anonymous lifter"; null author id → "Copied from another user"; null source id → "Copied from another user"; a workout generated from a copied program (`copiedFromWorkoutId` null, `copiedFromProgramId` set, author set) → names the author
- [X] T015 [P] Unit tests in `test/core/copy_errors_test.dart` covering each code mapping in T012
- [X] T016 [P] Extend `test/workouts/models_test.dart` and `test/programs/models_test.dart`: `fromJson` reads the new columns, and their absence defaults to `isCopy == false` and nulls
- [X] T017 [P] Widget test in `test/shared/copied_from_badge_test.dart`: renders the label for a copy and nothing for a non-copy

**Checkpoint**: The schema migrates cleanly, models parse copy fields, and the badge and labels are tested

---

## Phase 3: User Story 1 - Save a community workout and train it (Priority: P1) 🎯 MVP

**Goal**: A viewer saves another user's public workout as their own private, permanently marked copy

**Independent Test**: As `a@a.com`, open `b@b.com`'s public workout in Community, tap Save, and open the copy from Workouts. It has the badge, the same exercises, sets and notes, and percentage sets resolve against a's 1RM. b's original is unchanged.

### Tests for User Story 1

- [X] T018 [P] [US1] Extend `test/community/community_workout_detail_test.dart`:
  - Viewer ≠ owner: `Key('community_workout_save')` is shown.
  - Viewer == owner: no Save/Start (FR-018).
  - `workoutCopyCountProvider` overridden to 2: `Key('community_workout_saved_hint')` is shown and Save stays enabled (FR-013).
  - Tapping Save calls a stubbed `WorkoutsNotifier.saveCommunityWorkout` and shows a SnackBar with **View**.
  - A stub that throws shows the `copyErrorMessage` text with **Retry**.

  Use `ensureVisible` before taps.
- [X] T019 [P] [US1] Extend `test/workouts/workout_visibility_test.dart`: for a workout with `isCopy: true`, the Public switch on `EditWorkoutScreen` is disabled and shows "Copies of other people's content can't be shared."
- [X] T020 [P] [US1] Add widget tests (in `test/workouts/workouts_search_test.dart` or a new `test/workouts/workout_copy_badge_test.dart`): a copied workout shows `Key('copied_from_badge')` on its `WorkoutsScreen` card and on `WorkoutDetailScreen`, and a non-copy shows none
- [X] T021 [P] [US1] Widget test in `test/workouts/workout_copy_percentage_test.dart` (FR-020): `WorkoutDetailScreen` for a copied workout whose percentage set has a `basisExerciseId` the viewer doesn't own. Override `oneRepMaxProvider` (empty by id) and `oneRepMaxByNameProvider` (viewer's 1RM for that lift's name). The set must render the weight resolved from the **viewer's** 1RM via `formatResolvedWeight`. A second case with no viewer 1RM shows the no-1RM state, not zero

### Implementation for User Story 1

- [X] T022 [US1] In `MIGRATION`, create `public.copy_workout(p_source_workout_id uuid, p_today date, p_start boolean default false) returns uuid` (`language plpgsql security invoker set search_path = public`) per `contracts/rpc.md`.
  - **Pre-checks** (raise `'<code>: ...'`, no writes): `not_authenticated`; `not_found` when the source row isn't selectable or `is_public = false`; `own_content`; `source_is_copy`.
  - **Insert** the copy: `user_id = auth.uid()`, the source `title` and `notes`, `date = p_today` (the caller's local date; never `current_date`, which is UTC — research R11), `status = 'not_started'`, `is_public = false`, `is_copy = true`, `copied_from_user_id = source.user_id`, `copied_from_display_name = (select display_name from profiles where id = source.user_id)`, `copied_from_workout_id = source.id`. Use the default `workout_group_id`.
  - **Exercises**: copy each `workout_exercises` row ordered by `position` (`exercise_id` via `map_exercise_for_viewer`, plus `position`, `notes`, `user_id = auth.uid()`).
  - **Sets**: copy each `workout_sets` row (`position`, `target_reps`, `weight_mode`, `percentage`, `absolute_weight_kg`, `basis_exercise_id` via `map_exercise_for_viewer`, `note`, `user_id = auth.uid()`). **Do not** copy `completed` or `actual_*` (FR-006).
  - **Start**: if `p_start`, `perform public.start_workout_session(v_new_id)`.
  - Return the new id. Then re-run `supabase db reset` and `supabase db lint`.
- [X] T023 [US1] Create `workoutCopyCount(Ref ref, String sourceWorkoutId) → Future<int>` as an `@Riverpod(keepAlive: true)` family provider in `lib/features/workouts/providers/workout_copy_count_provider.dart`. It starts with `ref.watch(authStateProvider)`, returns 0 when signed out, and otherwise counts the viewer's `workouts` where `copied_from_workout_id = sourceWorkoutId`. In `WorkoutsNotifier.deleteWorkout()` (`lib/features/workouts/providers/workouts_provider.dart`), add `ref.invalidate(workoutCopyCountProvider)` to refresh the whole family, so the "saved N times" hint can't go stale after a copy is deleted (research R13)
- [X] T024 [US1] Add `Future<String> saveCommunityWorkout(String sourceWorkoutId, {bool start = false})` to `WorkoutsNotifier` in `lib/features/workouts/providers/workouts_provider.dart`.
  - Call `rpc('copy_workout', params: {'p_source_workout_id': ..., 'p_today': DateTime.now().toIso8601String().split('T').first, 'p_start': start})`. This is the same local-date expression `createWorkout()` uses.
  - Invalidate `exercisesProvider` and `workoutCopyCountProvider(sourceWorkoutId)`, plus `inProgressWorkoutsProvider` when `start`.
  - End with `ref.invalidateSelf(); await future;` and return the new id.
- [X] T025 [US1] Run `dart run build_runner build --delete-conflicting-outputs` to generate `workout_copy_count_provider.g.dart` and update `workouts_provider.g.dart`
- [X] T026 [US1] Add the save action to `CommunityWorkoutDetailScreen` in `lib/features/community/screens/community_workout_detail_screen.dart`.
  - Show it only when `workout.userId != currentUser.id`.
  - Button: "Save to my workouts", `Key('community_workout_save')`, `NomorexDarkTokens.secondaryButtonStyle`.
  - When `workoutCopyCountProvider(workoutId) > 0`, show "You've saved this N time(s)" with `Key('community_workout_saved_hint')`.
  - Disable the button with progress while in flight.
  - On success: SnackBar "Saved to your workouts" with a **View** action that pushes `AppConstants` workout-detail route for the new id.
  - On error: SnackBar with `copyErrorMessage(e)` and **Retry**.
  - Make the screen a `ConsumerStatefulWidget` if needed for busy state.
- [X] T027 [P] [US1] Show `CopiedFromBadge` on each workout card in `lib/features/workouts/screens/workouts_screen.dart` and in the header of `lib/features/workouts/screens/workout_detail_screen.dart`
- [X] T028 [P] [US1] In `lib/features/workouts/screens/edit_workout_screen.dart`, when `workout.isCopy`, set the Public `SwitchListTile`'s `onChanged: null` and add the subtitle "Copies of other people's content can't be shared." (FR-008)
- [X] T029 [US1] Add `Map<String, dynamic> copyAttributionColumns(Workout source)` to `lib/features/workouts/utils/workout_copier.dart`. It returns `{'is_copy': true, 'copied_from_user_id', 'copied_from_display_name', 'copied_from_workout_id', 'copied_from_program_id'}` from `source` when `source.isCopy`, else `{}`. Spread it into the workout insert in `WorkoutsNotifier.duplicateWorkout()` (`lib/features/workouts/providers/workouts_provider.dart`). Also spread it into both workout inserts in `lib/features/workouts/providers/workout_detail_provider.dart`: `finishWorkout()`'s next-instance insert and `repeatWorkout()`'s fallback insert (FR-008a, research R7). Extend the duplicate's `select` to include the new columns if it doesn't use `*`
- [X] T030 [US1] Run `flutter analyze` and `flutter test`; fix failures

**Checkpoint**: US1 is fully functional. A community workout can be saved, the copy is badged, can't be published, and keeps its copy status through duplicate and repeat

---

## Phase 4: User Story 2 - Start a community workout directly (Priority: P2)

**Goal**: One tap saves a copy and opens an in-progress session of it

**Independent Test**: As `a@a.com`, tap Start on b's public workout. You land in an in-progress session of a's own copy, and it shows in Home's in-progress workouts.

### Tests for User Story 2

- [X] T031 [P] [US2] Extend `test/community/community_workout_detail_test.dart`: `Key('community_workout_start')` is shown for non-owners and hidden for owners. Tapping it calls the stubbed `saveCommunityWorkout(id, start: true)` and navigates to the workout-detail route for the returned id (assert via a test `GoRouter`). Both buttons are disabled while in flight

### Implementation for User Story 2

- [X] T032 [US2] In `lib/features/community/screens/community_workout_detail_screen.dart`, add a "Start workout" `FilledButton` (`Key('community_workout_start')`, the primary action placed before Save). It calls `ref.read(workoutsProvider.notifier).saveCommunityWorkout(workoutId, start: true)`, then pushes the workout-detail route for the returned id. It shares busy state and error handling with Save (T026)
- [X] T033 [US2] Run `flutter analyze` and `flutter test test/community`; fix failures

**Checkpoint**: US1 and US2 both work

---

## Phase 5: User Story 3 - Save a community program (Priority: P2)

**Goal**: A viewer saves another user's public program as a private, permanently marked copy; workouts generated from that copy inherit copy status

**Independent Test**: As `a@a.com`, save b's public program and open it from Programs. All weeks and days (including the rest day) are in order, exercises and sets match, the badge shows, and Public is disabled.

### Tests for User Story 3

- [X] T034 [P] [US3] Extend `test/community/community_program_detail_test.dart`:
  - Non-owner sees `Key('community_program_save')`, and the "Read only" badge is gone.
  - Owner sees neither action.
  - `programCopyCountProvider` overridden to >0 shows `Key('community_program_saved_hint')`.
  - Tapping Save calls the stubbed `ProgramsNotifier.saveCommunityProgram` and shows a SnackBar with **View**.
  - The error path shows the `copyErrorMessage` text.
- [X] T035 [P] [US3] Extend `test/programs/program_edit_screen_test.dart` so that for `isCopy: true` the Public switch is disabled and shows the explanation subtitle. Extend `test/programs/programs_screen_test.dart` so a copied program card shows `Key('copied_from_badge')`

### Implementation for User Story 3

- [X] T036 [US3] In `MIGRATION`, create `public.copy_program(p_source_program_id uuid, p_start_date date default null) returns jsonb` (`language plpgsql security invoker set search_path = public`) per `contracts/rpc.md`.
  - **Pre-checks** (no writes): `not_authenticated`; `not_found` when not selectable or `is_public = false`; `own_content`; `archived` when `is_archived` (the `programs_select` policy does **not** hide archived rows); `source_is_copy`.
  - **Program row**: insert with `user_id = auth.uid()`, the source `name` and `description`, `is_public = false`, `is_archived = false`, `is_copy = true`, `copied_from_user_id`, `copied_from_display_name` (snapshot from `profiles`), and `copied_from_program_id = source.id`.
  - **Children**: walk weeks → days → exercises → sets ordered by `position`, keeping old→new id maps.
    - Copy `program_weeks` with `week_number`, `label`, `notes`, `position`.
    - Copy `program_days` with `day_number`, `title`, `is_rest_day`, `notes`, `position`, which is the global order (copy as-is, don't recompute).
    - Copy `program_exercises` with `exercise_id` via `map_exercise_for_viewer`, plus `position` and `notes`.
    - Copy `program_sets` with the same template columns as T022 and `basis_exercise_id` mapped.
  - Set `user_id = auth.uid()` on every row.
  - **Return** `jsonb_build_object('program_id', v_new_id, 'instance_id', null)`; leave a clearly marked spot for the start branch (T045).
  - **Columns**: confirm against the live schema in `20260805013756…`–`20260805013802…` and carry every template column.
- [X] T037 [US3] In `MIGRATION`, `create or replace function public.start_program(p_program_id uuid, p_start_date date)` with the body copied verbatim from `20260805020858_create_start_program_function.sql`. Use the **current** definition: confirm no later migration redefines `start_program` (none does as of planning). Change only one thing: the `insert into public.workouts` also sets `is_copy`, `copied_from_user_id`, `copied_from_display_name` and `copied_from_program_id` from the program row, read once into local variables before the loop. This is required for FR-008a. Keep `security invoker` and the ownership check unchanged
- [X] T038 [US3] Run `supabase db reset` and `supabase db lint`; fix any errors
- [X] T039 [US3] Create `programCopyCount(Ref ref, String sourceProgramId) → Future<int>` as an `@Riverpod(keepAlive: true)` family provider in `lib/features/programs/providers/program_copy_count_provider.dart`, starting with `ref.watch(authStateProvider)` and counting the viewer's **non-archived** `programs` where `copied_from_program_id = sourceProgramId` (research R13). Add `ref.invalidate(programCopyCountProvider)` (whole family) to `ProgramsNotifier.archiveProgram()` and `restoreProgram()`. Then add `Future<({String programId, String? instanceId})> saveCommunityProgram(String sourceProgramId, {DateTime? startDate})` to `ProgramsNotifier` in `lib/features/programs/providers/programs_provider.dart`.
  - Call `rpc('copy_program', params: {'p_source_program_id': ..., 'p_start_date': startDate?.toIso8601String().substring(0, 10)})` and parse the jsonb.
  - Invalidate `exercisesProvider` and `programCopyCountProvider(sourceProgramId)`; when started, also invalidate `currentProgramInstancesProvider` and any instances-list provider the dashboard watches (check `program_instances_list_provider.dart`).
  - End with `ref.invalidateSelf(); await future;`.

  Run `dart run build_runner build --delete-conflicting-outputs`.
- [X] T040 [US3] In `lib/features/community/screens/community_program_detail_screen.dart`, for non-owners, replace the "Read only" badge with a "Save to my programs" action (`Key('community_program_save')`, secondary button style) and add the saved hint (`Key('community_program_saved_hint')`). Busy state, success SnackBar with **View** (ProgramDetail route) and error handling work as in T026. Rewrite the class doc comment, which currently says starting was deliberately omitted, to describe the new save/start behavior
- [X] T041 [P] [US3] Show `CopiedFromBadge` on program cards in `lib/features/programs/screens/programs_screen.dart` and in the headers of `lib/features/programs/screens/program_detail_screen.dart` and `lib/features/programs/screens/program_edit_screen.dart`. In `program_edit_screen.dart`, when `program.isCopy`, disable the Public switch with the explanation subtitle (FR-008)
- [X] T042 [US3] Run `flutter analyze` and `flutter test`; fix failures

**Checkpoint**: US3 works on its own. Starting a saved program from the user's own Programs list already works (existing flow) and produces badged workouts

---

## Phase 6: User Story 4 - Start a community program (Priority: P3)

**Goal**: One action saves a copy and starts a dated run of it

**Independent Test**: As `a@a.com`, tap Start on b's program and pick today. You land on the program run screen, Home lists it under Current Programs, and its generated workouts show the badge.

### Tests for User Story 4

- [X] T043 [P] [US4] Extend `test/community/community_program_detail_test.dart`: `Key('community_program_start')` is shown for non-owners. Tapping it opens the start-date dialog; confirming calls the stubbed `saveCommunityProgram(id, startDate: ...)` and navigates to the program-instance route for the returned `instanceId`. Cancelling makes no call
- [X] T044 [P] [US4] Widget test in a new `test/programs/program_instance_detail_test.dart` showing that a `ProgramInstanceDetailScreen` for a copied program shows `Key('copied_from_badge')`

### Implementation for User Story 4

- [X] T045 [US4] In `MIGRATION`, fill the start branch of `copy_program` (T036): when `p_start_date is not null`, `v_instance_id := public.start_program(v_new_program_id, p_start_date)` and return it in `instance_id`. Run `supabase db reset` and `supabase db lint`
- [X] T046 [US4] Extract the start-date dialog from `ProgramDetailScreen._startProgram` (`lib/features/programs/screens/program_detail_screen.dart`) into `Future<DateTime?> showStartProgramDialog(BuildContext context, {required int dayCount})` in `lib/features/programs/widgets/start_program_dialog.dart`. Keep the same UI, date bounds and copy, and update `ProgramDetailScreen` to use it with no behavior change
- [X] T047 [US4] In `lib/features/community/screens/community_program_detail_screen.dart`, add the primary "Start program" `FilledButton` (`Key('community_program_start')`). It calls `showStartProgramDialog`, then on a date calls `ref.read(programsProvider.notifier).saveCommunityProgram(programId, startDate: date)`, shows "Program started.", and does `context.pushReplacement(AppConstants.routeProgramInstanceDetail(instanceId!))`. It shares busy and error handling with Save
- [X] T048 [P] [US4] Show `CopiedFromBadge` in the header of `lib/features/programs/screens/program_instance_detail_screen.dart`, using the instance's program attribution (extend `ProgramInstanceDetailNotifier`'s select to include the program's copy columns if not already selected via `*`)
- [X] T049 [US4] Run `flutter analyze` and `flutter test`; fix failures

**Checkpoint**: All four stories work

---

## Phase 7: Polish & Cross-Cutting Concerns

- [ ] T050 Ship the database first (Constitution V, research R12). Commit `MIGRATION` and `supabase/seed.sql` on their own, open **PR 1** containing only those two files, and merge it. Confirm the Supabase GitHub integration has applied the migration to production (Supabase dashboard migrations list, or `supabase migration list --linked`, which is read-only) before **PR 2** (all `lib/`, `test/` and `integration_test/` changes) is merged. If shipping only the MVP, PR 1 still contains the whole migration as written so far
- [X] T051 Add a `CommunityPage` page object in `integration_test/support/pages/community_page.dart`, or extend the existing one, with key-based actions: open a workout or program by title, save, start, and dismiss SnackBar/View
- [X] T052 Create the E2E test `integration_test/community_copy_test.dart`, signing in as `a@a.com` and using `waitFor`/`waitForAbsent` after every network action. It must:
  1. Save b's seeded public workout and see the copy with `copied_from_badge` in Workouts.
  2. Start b's workout and land in an in-progress session.
  3. Start b's program and land on the instance screen.
  4. Save b's workout a second time, then open the exercise picker and assert b's custom lift appears exactly once (`findsOneWidget`) — SC-006. This one exact-count assertion is rerun-safe: dedupe makes it one however many times the suite runs, so it doesn't break the "presence, not counts" rule's intent.
  5. Open the saved workout copy and assert each seeded exercise name and set row is present in seeded order (SC-004).

  Assert presence, not counts, everywhere else. Add the file to the loop in `scripts/e2e.sh` if it lists files explicitly
- [X] T053 Measure SC-003 in `integration_test/community_copy_test.dart`: wrap the "Save to my programs" action on b's 12-week seeded program (T008) in a `Stopwatch` from tap until the success SnackBar appears, print the duration, and `expect` it under 5 s on the local stack. If it's over, optimize `copy_program`. Before that, replace the per-set `map_exercise_for_viewer` calls with a one-time mapping of the program's distinct exercise ids (a temp table or `jsonb` map), and use set-based `insert … select` per level instead of row loops
- [X] T054 Run `./scripts/e2e.sh` locally; fix failures
- [X] T055 [P] Update `CLAUDE.md` with a short paragraph under Domain rules and Database.
  - What it should say: community content can be copied via `copy_workout`/`copy_program`; `is_copy` is permanent and blocks `is_public`; author names are snapshotted because `profiles_select` hides unpublished authors; new creation-from-existing paths must spread `copyAttributionColumns`.
  - Also update the `start_program` description to mention the copy-column stamping.
- [X] T056 Run the full gate: `flutter analyze`, `flutter test` (the full suite, because the community screens gained height; see the CLAUDE.md viewport note), `supabase db reset`, `supabase db lint`
- [ ] T057 Walk through the manual scenarios in `specs/001-save-community-content/quickstart.md` (web via claude-in-chrome for rendering; taps are covered by widget tests) and note any gaps

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies
- **Foundational (Phase 2)**: depends on Setup; blocks all stories
- **US1 (Phase 3)**: depends on Foundational
- **US2 (Phase 4)**: depends on US1 (reuses `copy_workout`, `saveCommunityWorkout`, and the screen's busy/error handling)
- **US3 (Phase 5)**: depends only on Foundational and can run in parallel with US1/US2. Its shared files are `MIGRATION` (sequential edits) and `edit`/`program` screens it owns
- **US4 (Phase 6)**: depends on US3
- **Polish (Phase 7)**: depends on all desired stories

### Within Each Story

Tests first, written to fail. Then SQL, then `db reset`/`lint`, then providers and `build_runner`, then UI, then analyze/test.

### Shared-file caution

`MIGRATION` is edited by T003–T006, T022, T036, T037 and T045. Those tasks must run one at a time even across stories. `community_workout_detail_screen.dart` is shared by T026/T032, and `community_program_detail_screen.dart` by T040/T047.

---

## Parallel Example: Foundational

```text
T009 Workout model fields      | T010 Program model fields
T011 copyAttributionLabel      | T012 copyErrorMessage
T014–T017 tests (after their targets)
```

## Parallel Example: User Story 1

```text
T018 community workout widget tests | T019 visibility test | T020 badge tests | T021 percentage test
T027 badge on list/detail           | T028 disable Public switch
```

## Parallel Example: US1 ∥ US3 (two developers)

```text
Dev A: T018 → T030 (workouts)      Dev B: T034 → T042 (programs)
       (coordinate MIGRATION edits T022 / T036–T037)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1 → Phase 2 → Phase 3 (US1)
2. **Stop and validate**: quickstart scenarios 1, 2, 4 and 5
3. Shippable: users can save community workouts. The migration deploys ahead of the app (Constitution V)

### Incremental Delivery

1. US1 → ship (save workouts)
2. US2 → ship (start workouts)
3. US3 → ship (save programs; starting a saved one already works via Programs)
4. US4 → ship (one-step start from Community)
5. Polish: E2E, CLAUDE.md, full gate

---

## Notes

- Never run `supabase db reset --linked`
- Every new provider that reads user data is `keepAlive` and watches `authStateProvider`
- Every new FAB in the shell needs a `heroTag`; none are planned here
- Commit after each phase with Conventional Commits (e.g. `feat(community): save public workouts to your library`)
