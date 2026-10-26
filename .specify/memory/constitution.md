# NoMoreX Constitution

## Core Principles

### I. User Data Isolation (NON-NEGOTIABLE)

A lifter's training history is private by default, and isolation is enforced by the database,
not trusted to the client.

- Every table in `public` MUST enable RLS with ownership policies
  `TO authenticated using ((select auth.uid()) = user_id)`; UPDATE policies MUST declare both
  `USING` and `WITH CHECK`.
- Child tables (`workout_exercises`, `workout_sets`, all `program_*`) MUST carry a denormalized
  `user_id`, and every insert MUST populate it.
- Every Riverpod provider that reads user data MUST be `@Riverpod(keepAlive: true)`, MUST
  `ref.watch(authStateProvider)` before reading `currentUser?.id`, and MUST return empty when
  there is no user.
- Server-side functions MUST be `SECURITY INVOKER` unless a written justification for
  `SECURITY DEFINER` is approved, so they stay gated by the same RLS a client insert would hit.
- `supabase db reset` MUST only ever run against the local stack. Any destructive operation on
  the linked/production project requires explicit, per-instance human confirmation.

**Rationale**: a missed `authStateProvider` watch or RLS policy leaks one user's data to another
silently; database-level enforcement is the only guarantee that survives client bugs.

### II. Training Data Integrity

The numbers a lifter programs against MUST be correct, or visibly absent — never silently wrong.

- Weights MUST be stored in kg everywhere and converted only at the display/input boundary via
  `weight_converter.dart` and the user's unit preference.
- Percentage-set resolution MUST go through `resolveSetWeightKg()` / `resolveBasisExerciseId()`;
  a missing 1RM MUST surface as `null` and be handled by the screen, never defaulted to zero.
- 1RM is derived from personal bests, never stored. Any weight resolved from an estimated 1RM
  MUST carry the estimate marker (`formatResolvedWeight()`).
- Across users, exercises MUST be matched by name (`lookupOneRepMax()`,
  `ensureExerciseByName()`), never by `exercises.id`.
- Programs MUST NOT be hard-deleted once they have instance history; "delete" archives.
- Position/sequence values MUST be derived from `max(existing) + 1`, never from a count.

**Rationale**: an incorrect load or a duplicated exercise corrupts training decisions and PR
history, and these failures don't crash — they just sit there being wrong.

### III. Follow the Established Architecture

New code MUST read like existing code; new abstractions require justification.

- Feature-first layout: `lib/features/<feature>/{models,providers,screens,widgets,utils}`, with
  cross-feature code in `lib/core/` and `lib/shared/`.
- No repository/service layer: notifiers call `Supabase.instance.client` directly, and mutations
  end with `ref.invalidateSelf(); await future;`.
- A mutation MUST invalidate every provider whose rendered output it changes, not only its own.
- Async providers read inside callbacks MUST use `await ref.read(p.future)`, not `.asData`.
- Models are hand-written immutable classes with `fromJson`; no code-generated serialization.
- Route paths MUST be constants in `app_constants.dart`; design tokens MUST live on the theme or
  `NomorexTokens`, never hardcoded at call sites. `colorScheme.secondary` is not a second
  color.
- Any FAB inside the shell MUST set an explicit `heroTag`.

**Rationale**: consistency is what lets a small codebase stay legible; most regressions here
come from code that skipped a convention the rest of the app depends on.

### IV. Tested Without the Network, Verified End-to-End

Behavior MUST be covered by tests that run deterministically in CI.

- Pure logic (resolvers, converters, model JSON) MUST have direct unit tests.
- Widget tests MUST stub data by subclassing generated notifiers and overriding `build()` via
  `ProviderScope` overrides; widget tests MUST NOT hit the network.
- Tap-driven behavior MUST be covered by widget tests; manual browser checks verify rendering
  only. Taps that may be off-screen MUST be preceded by `ensureVisible`.
- E2E tests (`integration_test/`) MUST go through page objects, target `Key`s, use
  `waitFor`/`waitForAbsent` after network work, assert presence rather than counts, and run only
  via `scripts/e2e.sh`.
- Bug fixes SHOULD include a regression test that fails without the fix.

**Rationale**: the app has no Supabase mock and canvas-rendered UI that resists automation;
these rules are what make the suite trustworthy anyway.

### V. Additive, Reversible Delivery

Changes MUST be safe to deploy in any order relative to each other.

- Schema lives in `supabase/migrations/`, created only with `supabase migration new`.
- Migrations and app code deploy independently and unordered, so migrations MUST be additive and
  ship ahead of code that depends on them; destructive schema changes require a multi-step plan.
- Every migration change MUST pass `supabase db reset` (local) and `supabase db lint` before
  merge.
- Changes to `@Riverpod` annotations require `build_runner`; generated `*.g.dart` files are
  committed.

**Rationale**: prod user data cannot be recreated, and the deploy pipeline gives no ordering
guarantee between the web app and the database.

## Technology & Domain Constraints

- **Stack**: Flutter (mobile + web), Riverpod with code generation, go_router, Supabase
  (Postgres + Auth). Changes to this stack require a constitution amendment.
- **Configuration**: Supabase URL/key are compile-time `--dart-define` values; secrets and
  per-machine env files (`.env*.json`) MUST NOT be committed.
- **Domain model**: Programs are authoring-time templates; Workouts remain the only logged
  entity. Starting a program materializes workouts via the `start_program` RPC in a single
  transaction.
- **Exercise catalog**: predefined exercises are shared; custom ones are user-scoped. Technique
  modifiers (tempo, pause) are notes on the base lift, not separate exercises, unless a lifter
  would track a distinct PR for them.
- **Responsive UI**: layouts MUST work on both sides of the 600px mobile breakpoint.

## Development Workflow & Quality Gates

- Commits MUST follow Conventional Commits. PR titles MUST be changelog-style, describing the
  user-facing change in plain language.
- Work happens on branches; `main` is updated only through pull requests.
- A PR MUST pass all `pr-checks.yml` jobs before merge: `flutter analyze`, `flutter test`, web
  and Android builds in release/debug/profile, `db-validate`, and `e2e`.
- After any UI change that adds height to a screen, the full widget-test suite MUST be re-run,
  not just the touched file.
- Reviews MUST check new providers for the auth watch, new tables for RLS, mutations for
  cross-provider invalidation, and new position fields for `max + 1` derivation.

## Governance

This constitution supersedes conflicting practices. `CLAUDE.md` is the runtime guidance file
that records the detailed conventions implementing these principles; when the two disagree, this
document wins and `CLAUDE.md` MUST be updated to match.

- **Amendments**: proposed via pull request that edits this file, includes a Sync Impact Report,
  and updates `CLAUDE.md` and any affected Spec Kit templates in the same or a follow-up PR.
- **Versioning**: semantic. MAJOR for removing or redefining a principle; MINOR for adding a
  principle/section or materially expanding guidance; PATCH for clarifications and wording.
- **Compliance**: every `/speckit-plan` MUST pass a Constitution Check against principles I–V
  before design and again after; violations MUST be recorded with justification in the plan's
  Complexity Tracking table or the plan MUST change.

**Version**: 1.0.0 | **Ratified**: 2026-10-12 | **Last Amended**: 2026-10-12
