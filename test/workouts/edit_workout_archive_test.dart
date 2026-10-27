import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nomorex/features/profile/providers/profile_provider.dart';
import 'package:nomorex/features/workouts/models/workout.dart';
import 'package:nomorex/features/workouts/providers/workout_detail_provider.dart';
import 'package:nomorex/features/workouts/providers/workouts_provider.dart';
import 'package:nomorex/features/workouts/screens/edit_workout_screen.dart';

class _TestWorkoutDetailNotifier extends WorkoutDetailNotifier {
  _TestWorkoutDetailNotifier(this._workout);
  final Workout _workout;
  @override
  Future<Workout> build(String workoutId) async => _workout;
}

class _RecordingWorkoutsNotifier extends WorkoutsNotifier {
  _RecordingWorkoutsNotifier({this.onArchive});
  final void Function(String id)? onArchive;

  @override
  Future<List<Workout>> build() async => const [];

  @override
  Future<void> archiveWorkout(Workout workout) async {
    onArchive?.call(workout.id);
  }
}

Workout _workout({String? programInstanceId}) => Workout(
  id: 'w1',
  userId: 'u1',
  title: 'Day 1',
  date: DateTime(2026, 7, 5),
  updatedAt: DateTime(2026, 7, 5),
  workoutGroupId: 'g1',
  programInstanceId: programInstanceId,
);

void main() {
  testWidgets(
    'archive icon is hidden for a workout materialized from a program',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workoutDetailProvider('w1').overrideWith(
              () => _TestWorkoutDetailNotifier(
                _workout(programInstanceId: 'pi1'),
              ),
            ),
            unitPreferenceProvider.overrideWithValue('kg'),
          ],
          child: const MaterialApp(home: EditWorkoutScreen(workoutId: 'w1')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('edit_workout_archive')), findsNothing);
    },
  );

  testWidgets(
    'tapping Archive archives the workout and navigates to the workouts list',
    (tester) async {
      String? archivedId;
      final router = GoRouter(
        initialLocation: '/w1/edit',
        routes: [
          GoRoute(
            path: '/w1/edit',
            builder: (_, _) => const EditWorkoutScreen(workoutId: 'w1'),
          ),
          GoRoute(
            path: '/shell/workouts',
            builder: (_, _) => const Text('destination:workouts'),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workoutDetailProvider(
              'w1',
            ).overrideWith(() => _TestWorkoutDetailNotifier(_workout())),
            workoutsProvider.overrideWith(
              () =>
                  _RecordingWorkoutsNotifier(onArchive: (id) => archivedId = id),
            ),
            unitPreferenceProvider.overrideWithValue('kg'),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('edit_workout_archive')));
      await tester.pumpAndSettle();

      expect(archivedId, 'w1');
      expect(find.text('destination:workouts'), findsOneWidget);
    },
  );
}
