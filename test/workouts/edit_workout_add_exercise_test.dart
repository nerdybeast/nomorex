import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/exercises/models/exercise.dart';
import 'package:nomorex/features/exercises/providers/exercises_provider.dart';
import 'package:nomorex/features/profile/providers/profile_provider.dart';
import 'package:nomorex/features/workouts/models/workout.dart';
import 'package:nomorex/features/workouts/providers/workout_detail_provider.dart';
import 'package:nomorex/features/workouts/screens/edit_workout_screen.dart';

/// Feeds the exercises list from a caller-controlled future so the test can
/// decide exactly when loading completes (before vs. after the dialog opens).
class _TestExercisesNotifier extends ExercisesNotifier {
  _TestExercisesNotifier(this._future, {this.onAddCustom});
  final Future<List<Exercise>> _future;
  final void Function(String name)? onAddCustom;
  @override
  Future<List<Exercise>> build() => _future;

  @override
  Future<Exercise> addCustomExercise(String name) async {
    onAddCustom?.call(name);
    return Exercise(id: 'new-custom', name: name, isPredefined: false);
  }
}

class _TestWorkoutDetailNotifier extends WorkoutDetailNotifier {
  _TestWorkoutDetailNotifier(this._workout, {this.onAddExercise});
  final Workout _workout;
  final void Function(String exerciseId)? onAddExercise;
  @override
  Future<Workout> build(String workoutId) async => _workout;

  @override
  Future<void> addExercise(String exerciseId) async {
    onAddExercise?.call(exerciseId);
  }
}

void main() {
  testWidgets(
    'add-exercise picker shows options even when exercises finish loading '
    'after the dialog is opened',
    (tester) async {
      final completer = Completer<List<Exercise>>();
      final workout = Workout(
        id: 'w1',
        userId: 'u1',
        title: 'Day 1',
        date: DateTime(2026, 7, 5),
        updatedAt: DateTime(2026, 7, 5),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exercisesProvider.overrideWith(
              () => _TestExercisesNotifier(completer.future),
            ),
            workoutDetailProvider('w1').overrideWith(
              () => _TestWorkoutDetailNotifier(workout),
            ),
            unitPreferenceProvider.overrideWithValue('kg'),
          ],
          child: const MaterialApp(
            home: EditWorkoutScreen(workoutId: 'w1'),
          ),
        ),
      );
      // Workout detail resolves; exercises are still loading (completer pending).
      await tester.pumpAndSettle();

      // Open the "Add exercise" dialog WHILE exercises are still loading.
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();

      // Exercises finish loading only now — after the dialog is already open.
      completer.complete(const [
        Exercise(id: 'e1', name: 'Bench Press', isPredefined: true),
      ]);
      await tester.pumpAndSettle();

      // Type into the picker and expect the option to surface. Scope to the
      // dialog since the screen now also has Title/Description TextFormFields
      // in the background.
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextFormField),
        ),
        'Bench',
      );
      await tester.pumpAndSettle();

      expect(find.text('Bench Press'), findsOneWidget);
    },
  );

  testWidgets(
    'typing a brand-new exercise name still surfaces "Add custom exercise" '
    'and saves it',
    (tester) async {
      final workout = Workout(
        id: 'w1',
        userId: 'u1',
        title: 'Day 1',
        date: DateTime(2026, 7, 5),
        updatedAt: DateTime(2026, 7, 5),
      );
      String? addedName;
      String? addedExerciseId;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exercisesProvider.overrideWith(
              () => _TestExercisesNotifier(
                Future.value(const [
                  Exercise(id: 'e1', name: 'Bench Press', isPredefined: true),
                ]),
                onAddCustom: (name) => addedName = name,
              ),
            ),
            workoutDetailProvider('w1').overrideWith(
              () => _TestWorkoutDetailNotifier(
                workout,
                onAddExercise: (id) => addedExerciseId = id,
              ),
            ),
            unitPreferenceProvider.overrideWithValue('kg'),
          ],
          child: const MaterialApp(
            home: EditWorkoutScreen(workoutId: 'w1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Typed name matches no existing exercise (no "Bench" substring), so
      // the autocomplete's options list would previously become empty —
      // hiding the whole overlay, including "Add custom exercise". Scope to
      // the dialog since the screen now also has Title/Description
      // TextFormFields in the background.
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextFormField),
        ),
        'Overhead Squat',
      );
      await tester.pumpAndSettle();

      expect(find.text('Add custom exercise'), findsOneWidget);

      await tester.tap(find.text('Add custom exercise'));
      await tester.pumpAndSettle();

      // The "Custom Exercise" dialog stacks on top of the still-open "Add
      // exercise" dialog, so scope to it specifically rather than matching
      // any TextField showing the typed text.
      final customExerciseDialog = find.ancestor(
        of: find.text('Custom Exercise'),
        matching: find.byType(AlertDialog),
      );
      expect(
        find.descendant(
          of: customExerciseDialog,
          matching: find.widgetWithText(TextField, 'Overhead Squat'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(
          of: customExerciseDialog,
          matching: find.widgetWithText(FilledButton, 'Add'),
        ),
      );
      await tester.pumpAndSettle();

      expect(addedName, 'Overhead Squat');
      expect(addedExerciseId, 'new-custom');
    },
  );
}
