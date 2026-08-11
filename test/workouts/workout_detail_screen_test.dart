import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nomorex/features/exercises/models/exercise.dart';
import 'package:nomorex/features/exercises/providers/exercises_provider.dart';
import 'package:nomorex/features/workouts/models/workout.dart';
import 'package:nomorex/features/workouts/models/workout_exercise.dart';
import 'package:nomorex/features/workouts/models/workout_set.dart';
import 'package:nomorex/features/workouts/providers/one_rep_max_provider.dart';
import 'package:nomorex/features/workouts/providers/workout_detail_provider.dart';
import 'package:nomorex/features/workouts/screens/workout_detail_screen.dart';

class _StubWorkoutDetailNotifier extends WorkoutDetailNotifier {
  _StubWorkoutDetailNotifier(this._workout, {this.onSetCompleted});
  final Workout _workout;
  final void Function(String setId, bool completed)? onSetCompleted;

  @override
  Future<Workout> build(String workoutId) async => _workout;

  @override
  Future<void> setCompleted(String setId, bool completed) async {
    onSetCompleted?.call(setId, completed);
  }
}

class _StubExercisesNotifier extends ExercisesNotifier {
  _StubExercisesNotifier(this._exercises);
  final List<Exercise> _exercises;

  @override
  Future<List<Exercise>> build() async => _exercises;
}

const _sumoDeadlift = Exercise(id: 'e1', name: 'Sumo Deadlift', isPredefined: true);

Workout _workoutWithPercentageSet() {
  return Workout(
    id: 'w1',
    userId: 'u1',
    title: 'Workout 1',
    date: DateTime(2026, 8, 10),
    updatedAt: DateTime(2026, 8, 10),
    exercises: const [
      WorkoutExercise(
        id: 'we1',
        workoutId: 'w1',
        exerciseId: 'e1',
        exerciseName: 'Sumo Deadlift',
        position: 0,
        sets: [
          WorkoutSet(
            id: 's1',
            workoutExerciseId: 'we1',
            position: 0,
            weightMode: 'percentage',
            targetReps: 5,
            percentage: 73,
          ),
        ],
      ),
    ],
  );
}

void main() {
  testWidgets('a percentage set with no 1RM shows a "set PR" link, not "set a 1RM"',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutDetailProvider('w1').overrideWith(
            () => _StubWorkoutDetailNotifier(_workoutWithPercentageSet()),
          ),
          oneRepMaxProvider.overrideWith((ref) async => {}),
          exercisesProvider.overrideWith(() => _StubExercisesNotifier([_sumoDeadlift])),
        ],
        child: const MaterialApp(home: WorkoutDetailScreen(workoutId: 'w1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('set a 1RM'), findsNothing);
    expect(find.textContaining('set a 1RM'), findsNothing);
    expect(find.text('set PR'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is InkWell && w.child is Text && (w.child as Text).data == 'set PR',
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping "set PR" navigates to the add-PR route for the basis exercise '
      'and does not also toggle the set', (tester) async {
    var toggled = false;

    // WorkoutDetailScreen's "set PR" link uses context.push, which needs a
    // GoRouter ancestor — a minimal two-route router stands in for the app's
    // real one, with a dummy destination screen that surfaces the query
    // param it was pushed with.
    final router = GoRouter(
      initialLocation: '/w1',
      routes: [
        GoRoute(path: '/w1', builder: (_, _) => const WorkoutDetailScreen(workoutId: 'w1')),
        GoRoute(
          path: '/prs/add',
          builder: (_, state) => Text('destination:${state.uri.queryParameters['exerciseId']}'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutDetailProvider('w1').overrideWith(
            () => _StubWorkoutDetailNotifier(
              _workoutWithPercentageSet(),
              onSetCompleted: (_, _) => toggled = true,
            ),
          ),
          oneRepMaxProvider.overrideWith((ref) async => {}),
          exercisesProvider.overrideWith(() => _StubExercisesNotifier([_sumoDeadlift])),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('set PR'));
    await tester.pumpAndSettle();

    expect(toggled, isFalse);
    expect(find.text('destination:e1'), findsOneWidget);
  });

  testWidgets('a percentage set with a resolvable 1RM shows the weight, not a link',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutDetailProvider('w1').overrideWith(
            () => _StubWorkoutDetailNotifier(_workoutWithPercentageSet()),
          ),
          oneRepMaxProvider.overrideWith((ref) async => {'e1': 100}),
          exercisesProvider.overrideWith(() => _StubExercisesNotifier([_sumoDeadlift])),
        ],
        child: const MaterialApp(home: WorkoutDetailScreen(workoutId: 'w1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('set PR'), findsNothing);
    expect(find.textContaining('73%'), findsOneWidget);
  });

  testWidgets(
      'a percentage set on an exercise the viewer cannot see shows plain '
      '"no PR recorded" text, not a link', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutDetailProvider('w1').overrideWith(
            () => _StubWorkoutDetailNotifier(_workoutWithPercentageSet()),
          ),
          oneRepMaxProvider.overrideWith((ref) async => {}),
          // The viewer's own exercise list does NOT contain 'e1' — e.g. this
          // is someone else's public workout referencing a custom exercise
          // only the workout's owner can see.
          exercisesProvider.overrideWith(() => _StubExercisesNotifier(const [])),
        ],
        child: const MaterialApp(home: WorkoutDetailScreen(workoutId: 'w1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('set PR'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) => w is InkWell && w.child is Text && (w.child as Text).data == 'set PR',
      ),
      findsNothing,
    );
    expect(find.textContaining('no PR recorded'), findsOneWidget);
  });
}
