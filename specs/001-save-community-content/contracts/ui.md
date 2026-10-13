# UI Contracts

Keys are for widget/E2E tests (Constitution IV: target keys, not text). Route constants live in
`app_constants.dart`; no new routes are needed.

## Community workout detail (`CommunityWorkoutDetailScreen`)

Shown only when `workout.userId != currentUser.id` (FR-018).

| Element | Key | Behavior |
|---|---|---|
| "Start workout" (filled, primary) | `community_workout_start` | `copy_workout(start: true)` → `context.go/push` to the copy's `WorkoutDetailScreen`. |
| "Save to my workouts" (secondary style, `NomorexDarkTokens.secondaryButtonStyle`) | `community_workout_save` | `copy_workout(start: false)` → SnackBar "Saved to your workouts" with **View** action → copy's detail. |
| "You've saved this N time(s)" hint | `community_workout_saved_hint` | Visible when the viewer has ≥1 copy of this source (FR-013). Buttons stay enabled. |

Both buttons disable and show progress while either call is in flight (no double submits). On
error: SnackBar with message from `contracts/rpc.md` and a **Retry** action.

## Community program detail (`CommunityProgramDetailScreen`)

Replaces the "Read only" badge with actions when the viewer isn't the owner. Updates the class
doc comment that says Start was deliberately omitted.

| Element | Key | Behavior |
|---|---|---|
| "Start program" (filled) | `community_program_start` | Opens the same start-date dialog as `ProgramDetailScreen._startProgram` (extract to a shared widget/function) → `copy_program(start_date)` → `pushReplacement` to `ProgramInstanceDetailScreen(instanceId)`. |
| "Save to my programs" (secondary) | `community_program_save` | `copy_program()` → SnackBar "Saved to your programs" with **View** → `ProgramDetailScreen(programId)`. |
| Saved hint | `community_program_saved_hint` | As for workouts. |

## Copy badge (`CopiedFromBadge`, `lib/shared/widgets/copied_from_badge.dart`)

Renders `copyAttributionLabel(...)` (data-model.md) with a small "copy" icon; renders nothing when
the item isn't a copy. Key: `copied_from_badge`.

Placed on:
- Workouts list cards (`WorkoutsScreen`) and `WorkoutDetailScreen` header.
- Programs list cards (`ProgramsScreen`) and `ProgramDetailScreen` / `ProgramEditScreen` header.
- `ProgramInstanceDetailScreen` header (run of a copied program).

## Public switch on copies

`EditWorkoutScreen` and `ProgramEditScreen` (and `NewProgramScreen` is unaffected — new programs
aren't copies): when `isCopy`, the Public `SwitchListTile` is disabled (`onChanged: null`) with
subtitle "Copies of other people's content can't be shared." Key: existing switch key +
assertion on disabled state.

## Notifier API (Dart)

```dart
// WorkoutsNotifier
Future<String> saveCommunityWorkout(String sourceWorkoutId, {bool start = false});

// ProgramsNotifier
Future<({String programId, String? instanceId})> saveCommunityProgram(
  String sourceProgramId, {DateTime? startDate});

// Existing-copies lookup (FR-013), auth-scoped keepAlive family providers.
// programCopyCount excludes archived copies. Both are invalidated (whole family)
// by saveCommunity*, WorkoutsNotifier.deleteWorkout, ProgramsNotifier.archiveProgram
// and ProgramsNotifier.restoreProgram.
@Riverpod(keepAlive: true) Future<int> workoutCopyCount(Ref ref, String sourceWorkoutId);
@Riverpod(keepAlive: true) Future<int> programCopyCount(Ref ref, String sourceProgramId);
```

Invalidations per research R10.
