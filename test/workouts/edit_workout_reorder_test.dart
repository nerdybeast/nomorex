import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/profile/providers/profile_provider.dart';
import 'package:nomorex/features/workouts/models/workout.dart';
import 'package:nomorex/features/workouts/models/workout_exercise.dart';
import 'package:nomorex/features/workouts/models/workout_set.dart';
import 'package:nomorex/features/workouts/providers/workout_detail_provider.dart';
import 'package:nomorex/features/workouts/screens/edit_workout_screen.dart';

class _TestWorkoutDetailNotifier extends WorkoutDetailNotifier {
  _TestWorkoutDetailNotifier(this._workout, {this.onReorderExercises, this.onReorderSets});
  final Workout _workout;
  final void Function(List<String> orderedExerciseIds)? onReorderExercises;
  final void Function(String workoutExerciseId, List<String> orderedSetIds)? onReorderSets;

  @override
  Future<Workout> build(String workoutId) async => _workout;

  @override
  Future<void> reorderExercises(List<String> orderedExerciseIds) async {
    onReorderExercises?.call(orderedExerciseIds);
  }

  @override
  Future<void> reorderSets(String workoutExerciseId, List<String> orderedSetIds) async {
    onReorderSets?.call(workoutExerciseId, orderedSetIds);
  }
}

void main() {
  testWidgets('dragging an exercise card\'s handle reorders exercises', (tester) async {
    List<String>? reordered;
    final workout = Workout(
      id: 'w1',
      userId: 'u1',
      title: 'Day 1',
      date: DateTime(2026, 7, 5),
      updatedAt: DateTime(2026, 7, 5),
      workoutGroupId: 'g1',
      exercises: const [
        WorkoutExercise(
          id: 'ex1',
          workoutId: 'w1',
          exerciseId: 'e1',
          exerciseName: 'Back Squat',
          position: 0,
        ),
        WorkoutExercise(
          id: 'ex2',
          workoutId: 'w1',
          exerciseId: 'e2',
          exerciseName: 'Front Squat',
          position: 1,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutDetailProvider('w1').overrideWith(
            () => _TestWorkoutDetailNotifier(
              workout,
              onReorderExercises: (ids) => reordered = ids,
            ),
          ),
          unitPreferenceProvider.overrideWithValue('kg'),
        ],
        child: const MaterialApp(home: EditWorkoutScreen(workoutId: 'w1')),
      ),
    );
    await tester.pumpAndSettle();

    final handles = find.byIcon(Icons.drag_handle);
    expect(handles, findsNWidgets(2));

    final drag = await tester.startGesture(tester.getCenter(handles.first));
    await tester.pump(kPressTimeout);
    for (var i = 0; i < 10; i++) {
      await drag.moveBy(const Offset(0, 50));
      await tester.pump();
    }
    await drag.up();
    await tester.pumpAndSettle();

    expect(reordered, isNotNull);
    expect(reordered, ['ex2', 'ex1']);
  });

  testWidgets('reordering sets inside an exercise card calls reorderSets with that '
      "exercise's id", (tester) async {
    String? capturedExerciseId;
    List<String>? capturedOrder;
    final workout = Workout(
      id: 'w1',
      userId: 'u1',
      title: 'Day 1',
      date: DateTime(2026, 7, 5),
      updatedAt: DateTime(2026, 7, 5),
      workoutGroupId: 'g1',
      exercises: const [
        WorkoutExercise(
          id: 'ex1',
          workoutId: 'w1',
          exerciseId: 'e1',
          exerciseName: 'Back Squat',
          position: 0,
          sets: [
            WorkoutSet(
              id: 'set14',
              workoutExerciseId: 'ex1',
              position: 0,
              weightMode: 'absolute',
              targetReps: 14,
              absoluteWeightKg: 50,
            ),
            WorkoutSet(
              id: 'set15',
              workoutExerciseId: 'ex1',
              position: 1,
              weightMode: 'absolute',
              targetReps: 15,
              absoluteWeightKg: 45,
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutDetailProvider('w1').overrideWith(
            () => _TestWorkoutDetailNotifier(
              workout,
              onReorderSets: (exerciseId, ids) {
                capturedExerciseId = exerciseId;
                capturedOrder = ids;
              },
            ),
          ),
          unitPreferenceProvider.overrideWithValue('kg'),
        ],
        child: const MaterialApp(home: EditWorkoutScreen(workoutId: 'w1')),
      ),
    );
    await tester.pumpAndSettle();

    final handles = find.byIcon(Icons.drag_handle);
    // One handle for the exercise card, one per set row.
    expect(handles, findsNWidgets(3));

    final drag = await tester.startGesture(tester.getCenter(handles.at(1)));
    await tester.pump(kPressTimeout);
    await drag.moveBy(const Offset(0, 100));
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();

    expect(capturedExerciseId, 'ex1');
    expect(capturedOrder, ['set15', 'set14']);
  });
}
