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
  _StubWorkoutDetailNotifier(
    this._workout, {
    this.onSetCompleted,
    this.onStart,
    this.onPause,
    this.onResume,
  });
  final Workout _workout;
  final void Function(String setId, bool completed)? onSetCompleted;
  final VoidCallback? onStart;
  final VoidCallback? onPause;
  final VoidCallback? onResume;

  @override
  Future<Workout> build(String workoutId) async => _workout;

  @override
  Future<void> setCompleted(String setId, bool completed) async {
    onSetCompleted?.call(setId, completed);
  }

  @override
  Future<void> startWorkout() async => onStart?.call();

  @override
  Future<void> pauseWorkout() async => onPause?.call();

  @override
  Future<void> resumeWorkout() async => onResume?.call();
}

class _StubExercisesNotifier extends ExercisesNotifier {
  _StubExercisesNotifier(this._exercises);
  final List<Exercise> _exercises;

  @override
  Future<List<Exercise>> build() async => _exercises;
}

const _sumoDeadlift = Exercise(id: 'e1', name: 'Sumo Deadlift', isPredefined: true);

Workout _workoutWithPercentageSet({
  String status = 'not_started',
  DateTime? startedAt,
  DateTime? pausedAt,
  DateTime? finishedAt,
  int totalPausedSeconds = 0,
  String? sessionNotes,
}) {
  return Workout(
    id: 'w1',
    userId: 'u1',
    title: 'Workout 1',
    date: DateTime(2026, 8, 10),
    updatedAt: DateTime(2026, 8, 10),
    status: status,
    startedAt: startedAt,
    pausedAt: pausedAt,
    finishedAt: finishedAt,
    totalPausedSeconds: totalPausedSeconds,
    sessionNotes: sessionNotes,
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

  Future<void> pumpDetailScreen(
    WidgetTester tester, {
    required Workout workout,
    void Function(String, bool)? onSetCompleted,
    VoidCallback? onStart,
    VoidCallback? onPause,
    VoidCallback? onResume,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutDetailProvider('w1').overrideWith(
            () => _StubWorkoutDetailNotifier(
              workout,
              onSetCompleted: onSetCompleted,
              onStart: onStart,
              onPause: onPause,
              onResume: onResume,
            ),
          ),
          oneRepMaxProvider.overrideWith((ref) async => {'e1': 100}),
          exercisesProvider.overrideWith(() => _StubExercisesNotifier([_sumoDeadlift])),
        ],
        child: const MaterialApp(home: WorkoutDetailScreen(workoutId: 'w1')),
      ),
    );
    // Deliberately bounded pumps, not pumpAndSettle(): an in-progress
    // workout renders an ElapsedTimer with a real (unpaused) 1-second
    // periodic ticker, which would keep scheduling frames forever and make
    // pumpAndSettle() hang/time out. A few pumps is enough to let the async
    // providers (workout, oneRepMax, exercises) resolve from loading to data.
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  testWidgets('not-started: shows "Start Workout" and a non-interactive checkbox',
      (tester) async {
    var toggled = false;
    await pumpDetailScreen(
      tester,
      workout: _workoutWithPercentageSet(),
      onSetCompleted: (_, _) => toggled = true,
    );

    expect(find.text('Start Workout'), findsOneWidget);
    expect(find.text('Pause'), findsNothing);
    expect(find.text('Finish'), findsNothing);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(toggled, isFalse);
  });

  testWidgets('not-started: tapping "Start Workout" calls startWorkout', (tester) async {
    var started = false;
    await pumpDetailScreen(tester, workout: _workoutWithPercentageSet(), onStart: () => started = true);

    await tester.tap(find.text('Start Workout'));
    await tester.pumpAndSettle();

    expect(started, isTrue);
  });

  testWidgets('in-progress: shows the timer, "Pause"/"Finish", and an interactive checkbox',
      (tester) async {
    var toggled = false;
    var paused = false;
    await pumpDetailScreen(
      tester,
      workout: _workoutWithPercentageSet(
        status: 'in_progress',
        startedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      onSetCompleted: (_, _) => toggled = true,
      onPause: () => paused = true,
    );

    expect(find.text('Start Workout'), findsNothing);
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Resume'), findsNothing);
    expect(find.text('Finish'), findsOneWidget);

    // pump(), not pumpAndSettle(): the running ElapsedTimer's real ticker
    // never stops on its own within this stub (see the note in _pump above).
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(toggled, isTrue);

    await tester.tap(find.text('Pause'));
    await tester.pump();
    expect(paused, isTrue);
  });

  testWidgets('paused: shows "Resume" instead of "Pause", checkbox stays interactive',
      (tester) async {
    var toggled = false;
    var resumed = false;
    final startedAt = DateTime.now().subtract(const Duration(minutes: 20));
    await pumpDetailScreen(
      tester,
      workout: _workoutWithPercentageSet(
        status: 'paused',
        startedAt: startedAt,
        pausedAt: startedAt.add(const Duration(minutes: 10)),
      ),
      onSetCompleted: (_, _) => toggled = true,
      onResume: () => resumed = true,
    );

    expect(find.text('Pause'), findsNothing);
    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Finish'), findsOneWidget);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(toggled, isTrue);

    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    expect(resumed, isTrue);
  });

  testWidgets('finished: shows a static duration and session notes, non-interactive checkbox',
      (tester) async {
    var toggled = false;
    final startedAt = DateTime(2026, 8, 10, 9, 0, 0);
    await pumpDetailScreen(
      tester,
      workout: _workoutWithPercentageSet(
        status: 'finished',
        startedAt: startedAt,
        finishedAt: startedAt.add(const Duration(minutes: 45)),
        sessionNotes: 'Great session',
      ),
      onSetCompleted: (_, _) => toggled = true,
    );

    expect(find.text('00:45:00'), findsOneWidget);
    expect(find.text('Great session'), findsOneWidget);
    expect(find.text('Start Workout'), findsNothing);
    expect(find.text('Pause'), findsNothing);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(toggled, isFalse);
  });

  testWidgets('edit icon is shown only when not-started', (tester) async {
    await pumpDetailScreen(tester, workout: _workoutWithPercentageSet());
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
  });

  testWidgets('edit icon is hidden once in progress', (tester) async {
    await pumpDetailScreen(
      tester,
      workout: _workoutWithPercentageSet(
        status: 'in_progress',
        startedAt: DateTime.now(),
      ),
    );
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });
}
