# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

NoMoreX — a Flutter (mobile + web) strength-training log backed by Supabase. Users record personal bests (PRs), build workouts out of exercises, and program sets either as an absolute load or as a percentage of their 1-rep max.

## Commands

Every `flutter` command that runs or builds app code needs the Supabase config injected at compile time (see "Configuration" below), otherwise the app builds fine but silently cannot reach Supabase.

```bash
flutter run --dart-define-from-file=.env.json        # production Supabase
flutter run --dart-define-from-file=.env.local.json  # local `supabase start` stack

flutter analyze                    # lints (flutter_lints + custom_lint/riverpod_lint)
flutter test                       # full suite
flutter test test/workouts/set_editor_test.dart                  # one file
flutter test --plain-name 'add-exercise picker shows options'    # one test

dart run build_runner build --delete-conflicting-outputs   # regenerate *.g.dart
dart run build_runner watch --delete-conflicting-outputs
```

`*.g.dart` files are committed. Any change to a `@Riverpod` annotation, provider name, or notifier signature requires a `build_runner` run before `flutter analyze` will pass.

Database (requires Docker + Supabase CLI):

```bash
supabase start
supabase migration new <name>   # never hand-name migration files
supabase db reset               # replay all migrations from scratch — do this before pushing
supabase db lint
supabase status                 # prints local URL + publishable key for .env.local.json
```

**Never run `supabase db reset` (or any `--linked` variant of it) against the production/linked project.** It drops and recreates the database, which deletes real user data. `db reset` defaults to `--local` and that's the only form that should ever run in this repo or in CI. If asked to reset the linked/remote project, always stop and ask for explicit confirmation first, and be clear that it is a destructive action that can delete user data.

## Configuration

`lib/main.dart` reads `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` via `String.fromEnvironment()`. These are **compile-time** constants, not runtime env vars — OS environment variables have no effect; the values must arrive via `--dart-define` / `--dart-define-from-file`. Unset values default to empty strings with no error. `.env.json` (prod) and `.env.local.json` (local stack) are gitignored and created per machine. Android emulators reach a local stack at `10.0.2.2`, not `127.0.0.1`. Full details in `docs/build.md`.

## Architecture

**Feature-first layout.** `lib/features/<feature>/{models,providers,screens,widgets,utils}`, with `lib/core/` (constants, theme, unit conversion, date formatting) and `lib/shared/widgets/` for cross-feature pieces. Features: `auth`, `dashboard`, `exercises`, `personal_bests`, `profile`, `shell`, `workouts`, `programs`.

**No repository/service layer.** Riverpod notifiers talk to `Supabase.instance.client` directly, and mutations end with `ref.invalidateSelf(); await future;` so callers can `await` a completed refetch. Follow that shape rather than introducing a data-access abstraction.

**Auth-scoped providers.** Every provider that reads user data is `@Riverpod(keepAlive: true)` and starts with `ref.watch(authStateProvider)` before reading `currentUser?.id`, returning empty when null. `authStateProvider` wraps `onAuthStateChange`. Omitting that watch leaks the previous user's data across a sign-out — keep it in any new data provider.

**Models are hand-written.** Plain immutable classes with a `fromJson` factory; no freezed or json_serializable. Nested Supabase selects (`select('*, workout_exercises(*, exercises(name))')`) are unpacked inside the parent's `fromJson`, which also sorts children by `position`. Match that pattern when adding a model.

**Routing** lives entirely in `lib/app.dart`. `RouterNotifier` listens to `authStateProvider` and redirects: unauthenticated users off any non-public route to `/`, authenticated users off `/` and `/login` to `/shell/home`. The shell tabs are a `StatefulShellRoute.indexedStack`; detail/edit/create routes sit outside the shell. All paths are constants in `lib/core/constants/app_constants.dart` — add new ones there, not as string literals.

**Responsive shell.** `AppShell` renders a `BottomAppBar` + centered FAB below 600px and a `NavigationRail` above it (`isMobile()` in `lib/shared/widgets/responsive_layout.dart`). Because the shell always renders its own FAB, **any FAB on a screen inside the shell must set an explicit `heroTag`** — the default sentinel collides during route transitions and can crash the framework. `test/workouts/fab_hero_tag_test.dart` and `test/programs/fab_hero_tag_test.dart` guard this. There are 5 shell tabs (Home, My PRs, Workouts, Community, Programs) — a 5th tab means updating both `AppShell`'s mobile icon `Row` and desktop `NavigationRail` destinations by hand, since there's no loop over a route config.

**Programs are authoring-time templates; Workouts stay the only runtime/logged entity — but a program run is tracked.** A `Program` is a reusable template (`programs -> program_weeks -> program_days -> program_exercises -> program_sets`, mirroring the `workouts -> workout_exercises -> workout_sets` shape one level deeper, minus logging fields). "Starting" a program calls the `start_program` RPC, which inserts a `program_instances` row and bulk-materializes the template into ordinary `workouts`/`workout_exercises`/`workout_sets` rows stamped with `program_instance_id`/`program_day_id` (see Database below) — logging itself is still just a normal workout through the existing screens. On top of that, the instance is surfaced back to the user: the dashboard's "Current Programs" section and `ProgramInstanceDetailScreen` (`lib/features/programs/screens/`) read active `program_instances` to show upcoming/in-progress status and highlight today's day (`isProgramDayToday` in `utils/program_progress.dart`), and `WorkoutsNotifier`'s query excludes any workout with a non-null `program_instance_id` so materialized workouts don't flood the general Workouts list — they're reachable only through the instance screen, whose day cards push straight to the real `WorkoutDetailScreen`. `SetEditor` (`lib/features/workouts/widgets/set_editor.dart`) is shared between editing a workout and authoring a program via the `EditableSetRow` DTO (`lib/shared/models/editable_set_row.dart`); `WorkoutSet.toEditableRow()` / `ProgramSet.toEditableRow()` map into it.

## Domain rules

- **Weights are stored in kg everywhere** (`weight_kg`, `absolute_weight_kg`, `actual_weight_kg`). Convert only at the display/input boundary using `lib/core/utils/weight_converter.dart` and the user's `unitPreferenceProvider` (from `profiles.unit_preference`, defaults to `'kg'`).
- **Sets have two weight modes.** `weight_mode = 'absolute'` uses `absolute_weight_kg`; `'percentage'` uses `percentage` against the lifter's 1RM. `resolveSetWeightKg()` in `features/workouts/utils/set_resolver.dart` is the single place that resolves this, and returns `null` when a percentage set has no 1RM to resolve against — screens must handle that null rather than defaulting to zero.
- **A percentage set's 1RM basis defaults to its own exercise, but can be a different one.** `workout_sets.basis_exercise_id` / `program_sets.basis_exercise_id` (nullable FK to `exercises`) let a set be programmed as e.g. "Front Squat @ 75% of Clean & Jerk". `resolveBasisExerciseId(set, exercise)` in `features/workouts/utils/set_resolver.dart` returns `set.basisExerciseId ?? exercise.exerciseId` — always look up `oneRepMaxProvider` by that, not by the set's own exercise id. The basis picker in `SetEditor`'s "Add sets (%)" dialog is unrestricted (any exercise in the catalog, not just ones already in the workout/program).
- **1RM is derived, not stored.** `oneRepMaxProvider` maps `exerciseId -> heaviest personal_bests row with reps = 1`. Personal bests are the source of truth for programming percentages.
- **Adding sets uses stepper inputs, not free text.** `SetEditor` (`lib/features/workouts/widgets/set_editor.dart`) uses the shared `NumberStepperField` (`lib/shared/widgets/number_stepper_field.dart`, tap +/- or type directly, floored at a sensible minimum) for sets/reps/percentage/weight — there's no shorthand grammar to parse. The percentage dialog renders one %1RM stepper per set so wave-loading (a different percentage per set) is still possible; `ParsedSet` (`lib/features/workouts/utils/parsed_set.dart`) is just the reps+percentage DTO passed to `WorkoutDetailNotifier.addPercentageSets`. The weight dialog collects sets/reps/weight together and calls `addAbsoluteSets`, converting from the display unit to kg first.
- **Exercises are shared or custom.** Rows with `is_predefined = true` are visible to everyone; custom ones are scoped by `user_id`. The list query is `.or('is_predefined.eq.true,user_id.eq.$userId')`.
- **Predefined exercises aren't managed by migrations.** They live in `supabase/seed.sql`, which only ever runs against local/CI stacks via `supabase db reset` — production's actual predefined rows were inserted manually and are not tracked in this repo. It's fine if `seed.sql` drifts from what's in production; it exists to give local dev and CI a representative list, not to be the source of truth.
- **Tempo/pause/technique modifiers aren't separate exercises.** "Pause Front Squat," "Tempo Snatch Deadlift," etc. all log against the base lift (e.g. "Front Squat") with the modifier captured as a note on the `workout_exercise`/`program_exercise` row — this keeps 1RM/PB tracking coherent. A modifier only earns its own `exercises` row when a competent lifter would track a separate PR for it (e.g. Hang Power Clean vs. Power Clean).
- **Programs have no hard delete.** "Delete" in the UI archives (`programs.is_archived = true`, reversible via restore) rather than issuing a real `DELETE` — `program_instances.program_id` uses `ON DELETE RESTRICT` as a database-level backstop, but the app itself never exposes hard delete once a program has instance history.

## Database

Schema is code under `supabase/migrations/`. Tables: `profiles`, `exercises`, `personal_bests`, `workouts`, `workout_exercises`, `workout_sets`, `programs`, `program_weeks`, `program_days`, `program_exercises`, `program_sets`, `program_instances`. `workout_exercises`, `workout_sets`, and all `program_*` tables carry a denormalized `user_id` so RLS can be enforced without joins — new inserts must populate it.

Any new table in `public` **must** enable RLS and add ownership policies `TO authenticated using ((select auth.uid()) = user_id)`, with UPDATE declaring both `USING` and `WITH CHECK`. `supabase db lint` runs in CI.

**Programs schema.** `programs -> program_weeks -> program_days -> program_exercises -> program_sets` mirrors `workouts -> workout_exercises -> workout_sets` one level deeper (`program_sets` has no `completed`/`actual_*` columns — those stay logging-only on `workout_sets`). `program_days.position` is the day's *global* order across the whole program (not just its week) and drives both drag-reorder and start-date materialization math; `day_number` is display-only and intentionally not unique per week, since two sessions (e.g. AM/PM) can share it. `workouts.program_instance_id` / `workouts.program_day_id` (both nullable, `ON DELETE SET NULL`) link a materialized workout back to the program run that generated it, without making logged history depend on the template surviving.

**`start_program(p_program_id, p_start_date)`** (in `20260805020858_create_start_program_function.sql`) is the first non-trivial server-side `plpgsql` function in this codebase beyond the existing trigger functions (`handle_new_user`, `set_updated_at`). It's `SECURITY INVOKER` (not `DEFINER`) so it stays gated by the same RLS a direct client insert would hit, and does the whole weeks→days→exercises→sets walk in one transaction — this is why "Start Program" is an RPC call rather than a client-side loop like `WorkoutsNotifier.duplicateWorkout()`: a multi-week program is large enough (dozens of workouts, hundreds of exercises/sets) that a sequential client-side version would be slow and have no rollback on partial failure. Every `program_day` materializes a `workouts` row, including empty rest days.

## CI/CD

- `.github/workflows/pr-checks.yml` — `flutter analyze`, `flutter test`, debug APK build, plus a `supabase db reset` + `db lint` job.
- `.github/workflows/deploy.yml` — on push to `main`, builds and publishes the web app to GitHub Pages (with `--base-href` set to the repo subpath).
- Migrations are deployed **separately**, by the Supabase GitHub integration watching `supabase/`. The two are unordered relative to each other, so ship additive migrations ahead of the code that depends on them.

## Testing

Widget tests stub data by **subclassing the generated notifier and overriding `build()`**, then passing it to `ProviderScope(overrides: [...])` — e.g. `workoutsProvider.overrideWith(() => _EmptyWorkoutsNotifier())`. Simple derived providers use `overrideWithValue` (`unitPreferenceProvider.overrideWithValue('kg')`). There is no Supabase mock; tests never hit the network. Pure logic (parsers, resolvers, model JSON) is tested directly without widgets.
