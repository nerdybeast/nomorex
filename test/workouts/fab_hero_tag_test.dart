import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/profile/providers/profile_provider.dart';
import 'package:nomorex/features/workouts/models/workout.dart';
import 'package:nomorex/features/workouts/providers/workout_detail_provider.dart';
import 'package:nomorex/features/workouts/providers/workouts_provider.dart';
import 'package:nomorex/features/workouts/screens/edit_workout_screen.dart';
import 'package:nomorex/features/workouts/screens/workouts_screen.dart';

// The app shell (which wraps every tab) has its own FloatingActionButton.
// Any FAB rendered by a workouts screen therefore coexists with the shell FAB
// and, if both use the default hero tag, collides during route transitions
// ("multiple heroes that share the same tag") — which can escalate to a hard
// framework crash. Each workout FAB must declare its own heroTag. (Neither
// screen here has one now: creating a workout goes through the shell, and
// Edit workout adds exercises with an in-page button.)

class _EmptyWorkoutsNotifier extends WorkoutsNotifier {
  @override
  Future<List<Workout>> build() async => const [];
}

class _StubWorkoutDetailNotifier extends WorkoutDetailNotifier {
  _StubWorkoutDetailNotifier(this._workout);
  final Workout _workout;
  @override
  Future<Workout> build(String workoutId) async => _workout;
}

void main() {
  testWidgets(
    'WorkoutsScreen renders no FAB of its own (the shell "+" is the only one)',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workoutsProvider.overrideWith(() => _EmptyWorkoutsNotifier()),
          ],
          child: const MaterialApp(home: WorkoutsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsNothing);
    },
  );

  testWidgets('EditWorkoutScreen renders no FAB (adding an exercise is an in-page button)', (
    tester,
  ) async {
    final workout = Workout(
      id: 'w1',
      userId: 'u1',
      title: 'Day 1',
      date: DateTime(2026, 7, 5),
      updatedAt: DateTime(2026, 7, 5),
      workoutGroupId: 'g1',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutDetailProvider(
            'w1',
          ).overrideWith(() => _StubWorkoutDetailNotifier(workout)),
          unitPreferenceProvider.overrideWithValue('kg'),
        ],
        child: const MaterialApp(home: EditWorkoutScreen(workoutId: 'w1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byKey(const Key('edit_workout_add_exercise')), findsOneWidget);
  });
}
