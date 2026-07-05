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
  _TestExercisesNotifier(this._future);
  final Future<List<Exercise>> _future;
  @override
  Future<List<Exercise>> build() => _future;
}

class _TestWorkoutDetailNotifier extends WorkoutDetailNotifier {
  _TestWorkoutDetailNotifier(this._workout);
  final Workout _workout;
  @override
  Future<Workout> build(String workoutId) async => _workout;
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

      // Type into the picker and expect the option to surface.
      await tester.enterText(find.byType(TextFormField), 'Bench');
      await tester.pumpAndSettle();

      expect(find.text('Bench Press'), findsOneWidget);
    },
  );
}
