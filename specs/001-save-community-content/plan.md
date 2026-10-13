# Implementation Plan: Save and Start Community Workouts and Programs

**Branch**: `001-save-community-content` | **Date**: 2026-10-12 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/001-save-community-content/spec.md`

## Summary

Let a user save — and optionally start — another user's public workout or program. A copy is a
normal workout/program owned by the viewer, marked permanently as a copy with a snapshot of the
original author's name, and it can never be made public. The copy (and the optional start) runs
server-side in one transaction via two new `SECURITY INVOKER` RPCs, `copy_workout` and
`copy_program`. They map exercises into the viewer's catalog by name and reuse the existing
`start_workout_session` / `start_program` functions. Copy status carries over to duplicates,
repeats and program-generated workouts. The database enforces "copies can't be public" with a
CHECK constraint, plus a trigger that stops a row from being un-marked as a copy.

## Technical Context

**Language/Version**: Dart SDK ^3.12.2 / Flutter 3.47.2; SQL (PostgreSQL `plpgsql`)

**Primary Dependencies**: flutter_riverpod 3 + riverpod_annotation 4 (codegen), supabase_flutter 2.8, go_router 17

**Storage**: Supabase Postgres — one additive migration (columns, constraint, trigger, 2 new RPCs, `start_program` replaced)

**Testing**: `flutter test` (unit + widget, notifier overrides, no network); `scripts/e2e.sh` (real local Supabase); `supabase db lint`

**Target Platform**: Flutter web + Android/iOS; desktop for E2E

**Project Type**: Mobile + web app with BaaS (no custom backend beyond SQL functions)

**Performance Goals**: save a 12-week × 6-day program in < 5 s (SC-003); a workout save feels instant (< 1 s)

**Constraints**: all-or-nothing copy/start (FR-011, FR-016); RLS-gated (`SECURITY INVOKER`); migrations deploy independently of app code

**Scale/Scope**: ≤ ~2,000 rows per program copy; 2 community screens, 6 owner screens touched; 2 notifiers extended

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Pre | Post-design |
|---|---|---|---|
| I. User Data Isolation | New columns live on tables with existing ownership RLS; RPCs are `SECURITY INVOKER`; every insert sets `user_id = auth.uid()`; source read only through existing public-read policies; copies are forced private by CHECK and trigger. | ✅ | ✅ |
| II. Training Data Integrity | Weights copied in kg verbatim; percentage sets keep `weight_mode`/`percentage` and resolve against the viewer's 1RM; exercises and basis exercises mapped **by name** (R4); programs never hard-deleted; positions copied from a valid source, not recomputed by count. | ✅ | ✅ |
| III. Established Architecture | Logic in existing notifiers (`WorkoutsNotifier`, `ProgramsNotifier`) calling Supabase directly; hand-written model fields; cross-provider invalidation listed (R10); new widget in `lib/shared/widgets/`; blue secondary action via `NomorexDarkTokens.secondaryButtonStyle`; no new routes. | ✅ | ✅ |
| IV. Testing | Unit (model JSON, label helper), widget (community buttons and visibility, badge, disabled Public switch) with `overrideWith` stubs; E2E through page objects and keys, asserting presence. SQL covered by E2E + lint (no pgTAP harness exists — R9). | ✅ | ✅ |
| V. Additive Delivery | Migration only adds nullable/defaulted columns, a CHECK every existing row satisfies (`is_copy` defaults false), new functions, and a signature-compatible `start_program` replacement. Old app versions keep working; it ships before the app code. | ✅ | ✅ |

No violations, so Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/001-save-community-content/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── rpc.md
│   └── ui.md
├── checklists/requirements.md
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
supabase/
├── migrations/<timestamp>_add_content_copies.sql   # via `supabase migration new`
└── seed.sql                                        # + public workout & program owned by b@b.com

lib/
├── core/utils/copy_attribution.dart                # copyAttributionLabel() (pure)
├── shared/widgets/copied_from_badge.dart           # CopiedFromBadge
├── features/workouts/
│   ├── models/workout.dart                         # + isCopy, copiedFrom* fields
│   ├── utils/workout_copier.dart                   # + copyAttributionColumns(Workout)
│   ├── providers/workouts_provider.dart            # + saveCommunityWorkout(); duplicate carries attribution
│   ├── providers/workout_detail_provider.dart      # finish/repeat inserts carry attribution
│   ├── providers/workout_copy_count_provider.dart  # FR-013
│   └── screens/{workouts_screen,workout_detail_screen,edit_workout_screen}.dart
├── features/programs/
│   ├── models/program.dart                         # + isCopy, copiedFrom* fields
│   ├── providers/programs_provider.dart            # + saveCommunityProgram()
│   ├── providers/program_copy_count_provider.dart  # FR-013
│   ├── widgets/start_program_dialog.dart           # extracted from ProgramDetailScreen
│   └── screens/{programs_screen,program_detail_screen,program_edit_screen,program_instance_detail_screen}.dart
└── features/community/screens/
    ├── community_workout_detail_screen.dart        # Save / Start actions + saved hint
    └── community_program_detail_screen.dart        # Save / Start actions + saved hint

test/
├── core/copy_attribution_test.dart
├── workouts/models_test.dart, workout_visibility_test.dart (extend)
├── programs/models_test.dart, program_edit_screen_test.dart (extend)
├── shared/copied_from_badge_test.dart
└── community/community_{workout,program}_detail_test.dart (extend)

integration_test/
├── community_copy_test.dart
└── support/pages/community_page.dart (new or extended)
```

**Structure Decision**: The existing feature-first Flutter layout. Server logic goes in a single
new migration. No new feature folder: saving belongs to the owning features (workouts,
programs), and the entry points belong to community.

## Delivery order

Two PRs (research R12, Constitution V):

**PR 1 — database**: the migration and seed changes only. Merge it and confirm the Supabase
integration has applied the migration to production before PR 2 merges. It's additive, so
existing clients ignore the new columns.

**PR 2 — app**, in this order:
1. Models, label helper and badge (read-only display).
2. Save/Start notifiers and community screen actions.
3. Inheritance in client-side duplicate, finish and repeat; disabled Public switch.
4. E2E test and the copy-speed measurement (SC-003).

## Complexity Tracking

None.
