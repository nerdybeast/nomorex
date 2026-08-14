import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/community/providers/community_workout_detail_provider.dart';
import 'package:nomorex/features/community/screens/community_workout_detail_screen.dart';
import 'package:nomorex/features/profile/providers/profile_provider.dart';
import 'package:nomorex/features/workouts/models/workout.dart';
import 'package:nomorex/features/workouts/models/workout_exercise.dart';
import 'package:nomorex/features/workouts/models/workout_set.dart';

class _StubCommunityWorkoutDetailNotifier extends CommunityWorkoutDetailNotifier {
  _StubCommunityWorkoutDetailNotifier(this._workout);
  final Workout _workout;
  @override
  Future<Workout> build(String workoutId) async => _workout;
}

void main() {
  testWidgets('renders exercises and sets read-only, with no edit affordances',
      (tester) async {
    final workout = Workout(
      id: 'w1',
      userId: 'other-user',
      title: 'Squat Focus',
      date: DateTime(2026, 7, 5),
      updatedAt: DateTime(2026, 7, 5),
      workoutGroupId: 'g1',
      isPublic: true,
      exercises: const [
        WorkoutExercise(
          id: 'we1',
          workoutId: 'w1',
          exerciseId: 'e1',
          exerciseName: 'Back Squat',
          position: 0,
          sets: [
            WorkoutSet(
              id: 's1',
              workoutExerciseId: 'we1',
              position: 0,
              weightMode: 'percentage',
              targetReps: 5,
              percentage: 80,
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          communityWorkoutDetailProvider('w1').overrideWith(
            () => _StubCommunityWorkoutDetailNotifier(workout),
          ),
          unitPreferenceProvider.overrideWithValue('kg'),
        ],
        child: const MaterialApp(home: CommunityWorkoutDetailScreen(workoutId: 'w1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Squat Focus'), findsOneWidget);
    expect(find.text('Back Squat'), findsOneWidget);
    expect(find.text('5 reps · 80% 1RM'), findsOneWidget);

    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.byType(IconButton), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
  });
}
