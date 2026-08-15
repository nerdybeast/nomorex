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

**Visually testing the web app via claude-in-chrome:** `flutter run -d chrome --dart-define-from-file=.env.local.json --web-port=<PORT>` launches its own dedicated Chrome instance for Flutter's debug service — that instance is not the one claude-in-chrome controls. Run it in the background, then navigate a claude-in-chrome-controlled tab to `http://localhost:<PORT>` directly; it's a normal web server, so any browser tab can load the running app there. Requires the local Supabase stack up (`supabase start`) first.

Expect **rendering** to be verifiable this way and **tapping** not to be. Navigating straight to a route via the URL hash (`http://localhost:<PORT>/#/community/<id>`) reliably lands on any screen, and a signed-in session persists across reloads. But synthetic clicks land inconsistently on Flutter's canvas: large `FilledButton`s and the DOM-backed login inputs work, while list tiles and inline `WidgetSpan`-wrapped `InkWell`s can silently do nothing — no console error, no navigation — and dispatching `PointerEvent`s at `<flutter-view>` via the JS tool doesn't help either. Use the browser to confirm what a screen *looks* like, cover tap-driven behavior with widget tests, and after 2-3 failed clicks say plainly what's unverified rather than retrying.

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

**Feature-first layout.** `lib/features/<feature>/{models,providers,screens,widgets,utils}`, with `lib/core/` (constants, theme, unit conversion, date formatting) and `lib/shared/widgets/` for cross-feature pieces. Features: `auth`, `community`, `dashboard`, `exercises`, `personal_bests`, `profile`, `shell`, `workouts`, `programs`.

**No repository/service layer.** Riverpod notifiers talk to `Supabase.instance.client` directly, and mutations end with `ref.invalidateSelf(); await future;` so callers can `await` a completed refetch. Follow that shape rather than introducing a data-access abstraction.

**`invalidateSelf()` is rarely enough — several keepAlive providers cache the same rows.** `workoutsProvider`, `inProgressWorkoutsProvider`, `finishedWorkoutsProvider` and `communityWorkoutsProvider` all run their own `select('*, workout_exercises(*, exercises(name))')`, so a workout's exercises are cached in as many places as there are lists showing it. A mutation must invalidate every provider whose *rendered output* changes, not just the one it was called on: `WorkoutDetailNotifier.addExercise`/`removeExercise` invalidate `workoutsProvider` because the Workouts list renders `w.exercises.length`, and `PersonalBestsNotifier.addPr` invalidates both `oneRepMaxProvider` and `oneRepMaxByNameProvider`. Skipping this doesn't fail loudly — the stale value just sits there until some unrelated mutation happens to refetch, which is why "it's wrong until I refresh the page" bugs in this codebase are almost always a missing cross-provider `ref.invalidate`.

**Reading an async provider inside a callback: `await ref.read(p.future)`, not `ref.read(p).asData?.value`.** These providers are `keepAlive` but still lazy, so if nothing in the current screen `watch`es one, `.asData` is `null` at the moment a tap handler runs — indistinguishable from a legitimately empty result. `SetPrLink` (`lib/shared/widgets/set_pr_link.dart`) awaits the future for exactly this reason: treating "not loaded yet" as "the user doesn't have this exercise" would silently create a duplicate.

**Auth-scoped providers.** Every provider that reads user data is `@Riverpod(keepAlive: true)` and starts with `ref.watch(authStateProvider)` before reading `currentUser?.id`, returning empty when null. `authStateProvider` wraps `onAuthStateChange`. Omitting that watch leaks the previous user's data across a sign-out — keep it in any new data provider.

**Models are hand-written.** Plain immutable classes with a `fromJson` factory; no freezed or json_serializable. Nested Supabase selects (`select('*, workout_exercises(*, exercises(name))')`) are unpacked inside the parent's `fromJson`, which also sorts children by `position`. Match that pattern when adding a model.

**Routing** lives entirely in `lib/app.dart`. `RouterNotifier` listens to `authStateProvider` and redirects: unauthenticated users off any non-public route to `/`, authenticated users off `/` and `/login` to `/shell/home`. The shell tabs are a `StatefulShellRoute.indexedStack`; detail/edit/create routes sit outside the shell. All paths are constants in `lib/core/constants/app_constants.dart` — add new ones there, not as string literals.

**Theme: one accent, so `ColorScheme.secondary` is a trap.** `AppDarkTheme.sleekOrange()` (`lib/core/theme/dark_theme.dart`) deliberately pins `secondary`/`tertiary` and every `*Container` role to the orange primary, so stock M3 widgets the app hasn't themed don't fall back to Material's baseline purple/teal. Reaching for `colorScheme.secondary` to get "the other color" therefore silently gets you orange. Anything the design system defines that has no stock `ThemeData`/`ColorScheme` slot lives on the `NomorexDarkTokens` theme extension instead — the blue is `secondaryAccent` (bare color, for inline text) and `secondaryButtonStyle` (whole button style). Add new design tokens there rather than hardcoding a `Color` at the call site.

**Responsive shell.** `AppShell` renders a `BottomAppBar` + centered FAB below 600px and a `NavigationRail` above it (`isMobile()` in `lib/shared/widgets/responsive_layout.dart`). Because the shell always renders its own FAB, **any FAB on a screen inside the shell must set an explicit `heroTag`** — the default sentinel collides during route transitions and can crash the framework. `test/workouts/fab_hero_tag_test.dart` and `test/programs/fab_hero_tag_test.dart` guard this. There are 5 shell tabs (Home, My PRs, Workouts, Community, Programs) — a 5th tab means updating both `AppShell`'s mobile icon `Row` and desktop `NavigationRail` destinations by hand, since there's no loop over a route config.

**Programs are authoring-time templates; Workouts stay the only runtime/logged entity — but a program run is tracked.** A `Program` is a reusable template (`programs -> program_weeks -> program_days -> program_exercises -> program_sets`, mirroring the `workouts -> workout_exercises -> workout_sets` shape one level deeper, minus logging fields). "Starting" a program calls the `start_program` RPC, which inserts a `program_instances` row and bulk-materializes the template into ordinary `workouts`/`workout_exercises`/`workout_sets` rows stamped with `program_instance_id`/`program_day_id` (see Database below) — logging itself is still just a normal workout through the existing screens. On top of that, the instance is surfaced back to the user: the dashboard's "Current Programs" section and `ProgramInstanceDetailScreen` (`lib/features/programs/screens/`) read active `program_instances` to show upcoming/in-progress status and highlight today's day (`isProgramDayToday` in `utils/program_progress.dart`), and `WorkoutsNotifier`'s query excludes any workout with a non-null `program_instance_id` so materialized workouts don't flood the general Workouts list — they're reachable only through the instance screen, whose day cards push straight to the real `WorkoutDetailScreen`. `SetEditor` (`lib/features/workouts/widgets/set_editor.dart`) is shared between editing a workout and authoring a program via the `EditableSetRow` DTO (`lib/shared/models/editable_set_row.dart`); `WorkoutSet.toEditableRow()` / `ProgramSet.toEditableRow()` map into it.

## Domain rules

- **Weights are stored in kg everywhere** (`weight_kg`, `absolute_weight_kg`, `actual_weight_kg`). Convert only at the display/input boundary using `lib/core/utils/weight_converter.dart` and the user's `unitPreferenceProvider` (from `profiles.unit_preference`, defaults to `'kg'`).
- **Sets have two weight modes.** `weight_mode = 'absolute'` uses `absolute_weight_kg`; `'percentage'` uses `percentage` against the lifter's 1RM. `resolveSetWeightKg()` in `features/workouts/utils/set_resolver.dart` is the single place that resolves this, and returns `null` when a percentage set has no 1RM to resolve against — screens must handle that null rather than defaulting to zero.
- **A percentage set's 1RM basis defaults to its own exercise, but can be a different one.** `workout_sets.basis_exercise_id` / `program_sets.basis_exercise_id` (nullable FK to `exercises`) let a set be programmed as e.g. "Front Squat @ 75% of Clean & Jerk". `resolveBasisExerciseId(set, exercise)` in `features/workouts/utils/set_resolver.dart` returns `set.basisExerciseId ?? exercise.exerciseId` — always look up `oneRepMaxProvider` by that, not by the set's own exercise id. The basis picker in `SetEditor`'s "Add sets (%)" dialog is unrestricted (any exercise in the catalog, not just ones already in the workout/program).
- **1RM is derived, not stored.** `oneRepMaxProvider` maps `exerciseId -> heaviest personal_bests row with reps = 1`. Personal bests are the source of truth for programming percentages.
- **An `exercises.id` only means something inside one user's catalog — across users, match on name.** Two users who both have a custom "dude pulls" have two unrelated rows with different ids (there's no unique constraint on `name`, so duplicates by name are expected, not a data error). This matters everywhere a viewer looks at someone else's data: a public workout's `workout_sets.basis_exercise_id` points at the *owner's* exercise, while the viewer's PR for the same lift hangs off *their* id, so an id-keyed lookup silently misses forever. Resolve a viewer-facing 1RM through `lookupOneRepMaxKg()` (`features/workouts/utils/set_resolver.dart`), which tries `oneRepMaxProvider` by id and then falls back to `oneRepMaxByNameProvider` by lowercased name; when a viewer needs their *own* row for a foreign exercise, go through `ExercisesNotifier.ensureExerciseByName()`, which find-or-creates by name. The two halves must agree on name matching or a user can record a PR that never resolves anything.
- **Percentage sets on another user's workout resolve against the *viewer's* 1RM.** `CommunityWorkoutDetailScreen` is a preview of "what would this session cost me", not a transcript of what it cost its author — the resolved weight renders in `NomorexDarkTokens.secondaryAccent` (blue), absolute-weight sets stay default-colored because they're the same load for everyone, and a set with no resolvable 1RM offers the `SetPrLink` shortcut instead. `WorkoutDetailScreen` also renders other users' public workouts and follows the same rules.
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

**Position/sequence fields must be derived from `max(existing) + 1`, not a count.** `ProgramDetailNotifier.addWeek`/`addDay` (`lib/features/programs/providers/program_detail_provider.dart`) used to compute the next `week_number`/`position` from `weeks.length`/`totalDays`. Deleting a week or day from the middle of a program left the count behind the highest number still in use, so the next insert collided with a surviving row and threw on the `program_weeks_program_id_week_number_key` / `program_days` position unique constraint — fixed by deriving from `max(existing) + 1` instead. The same "position = count" shape still exists in `addDay`'s `day_number: week.days.length + 1` (harmless — `day_number` is intentionally not unique) and `addExercise`'s `position: day.exercises.length` (`program_exercises.position` has no unique constraint either, so it won't crash, but can still produce silently wrong ordering after a mid-list delete). Treat any new `position`/`order` assignment in this codebase with the same suspicion.

## CI/CD

- `.github/workflows/pr-checks.yml` — four parallel jobs, no `needs:` between them: `checks` (`flutter analyze`, `flutter test`, release web build), `build-android` (debug APK), `db-validate` (`supabase db reset` + `db lint`), and `e2e` (see E2E tests below). The Android build is deliberately its own job — the Gradle build dominated `checks` and was delaying analyze/test feedback. Only `build-android` sets up Java; the other jobs don't need it.
- `.github/workflows/deploy.yml` — on push to `main`, builds and publishes the web app to GitHub Pages (with `--base-href` set to the repo subpath).
- Migrations are deployed **separately**, by the Supabase GitHub integration watching `supabase/`. The two are unordered relative to each other, so ship additive migrations ahead of the code that depends on them.

## Testing

Widget tests stub data by **subclassing the generated notifier and overriding `build()`**, then passing it to `ProviderScope(overrides: [...])` — e.g. `workoutsProvider.overrideWith(() => _EmptyWorkoutsNotifier())`. Simple derived providers use `overrideWithValue` (`unitPreferenceProvider.overrideWithValue('kg')`). There is no Supabase mock; tests never hit the network. Pure logic (parsers, resolvers, model JSON) is tested directly without widgets.

### E2E tests (`integration_test/`)

`flutter test` only runs `test/`; the E2E suite is separate and always goes through its runner:

```bash
./scripts/e2e.sh          # macOS desktop (default)
./scripts/e2e.sh linux    # Linux desktop, how CI runs it
```

The script starts the local stack, runs `supabase db reset` (local only — never `--linked`), then runs each test file. Unlike widget tests, these boot the **real app against real Supabase**: no provider is stubbed. That's forced by `RouterNotifier.redirect` in `lib/app.dart`, which reads `Supabase.instance.client.auth.currentSession` directly rather than through a provider, so it can't be overridden — anything past `/` needs a genuine session. Tests sign in as the seeded `a@a.com` / `123456`.

Rules for adding to the suite:

- **Never call `flutter test integration_test` on the whole directory.** Each file launches a real desktop app window, and a second launch inside one invocation fails with `Unable to start the app on the device`. `scripts/e2e.sh` loops one invocation per file for this reason.
- **Go through a page object** in `integration_test/support/pages/`, never raw finders in a test body.
- **Target keys, not text**, for anything you interact with — add a `Key('screen_thing')` to the widget in `lib/` as needed. Nav tabs and bottom-sheet entries are the exception; their labels are unambiguous.
- **Use `waitFor` / `waitForAbsent` from `support/harness.dart`** after anything that hits the network. A bare `pumpAndSettle` blocks on the spinner that's still on screen and reports a far less useful failure.
- **Assert presence, not counts.** The suite must stay green re-run against a stack that wasn't freshly reset.
- The harness initializes Supabase with `EmptyLocalStorage` so sessions never persist to disk. Don't remove that: with the default storage, a session from a previous run is restored *asynchronously* during `initialize` and races the sign-out, which makes only the first test of a run fail.
- Both desktop targets are wider than the 600px `kMobileBreakpoint`, so these exercise `AppShell`'s `NavigationRail` branch. The mobile `BottomAppBar` branch stays widget-test territory.

**Widget tests render in `flutter_test`'s default ~800x600 surface.** A screen taller than that (nested `ExpansionTile`s, long lists) can push a target below the visible area — `tester.tap(finder)` on an off-screen widget doesn't throw, it just misses (a "hit test warning" that's easy to miss in the output), and the real failure surfaces later as something confusing and unrelated-looking, e.g. `Bad state: No element` from `enterText`/`showKeyboard` because a dialog never actually opened. Call `await tester.ensureVisible(finder); await tester.pumpAndSettle();` before tapping anything that might sit below the fold. After any UI change that adds height to a screen (more padding, more content), re-run the full suite rather than just the file touched — layout-adjacent tests can break invisibly.
