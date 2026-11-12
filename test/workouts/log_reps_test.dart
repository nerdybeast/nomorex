import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/exercises/models/exercise.dart';
import 'package:nomorex/features/exercises/providers/exercises_provider.dart';
import 'package:nomorex/features/workouts/models/workout.dart';
import 'package:nomorex/features/workouts/models/workout_exercise.dart';
import 'package:nomorex/features/workouts/models/workout_set.dart';
import 'package:nomorex/features/workouts/providers/finished_workouts_provider.dart';
import 'package:nomorex/features/workouts/providers/one_rep_max_provider.dart';
import 'package:nomorex/features/workouts/providers/workout_detail_provider.dart';
import 'package:nomorex/features/workouts/screens/workout_detail_screen.dart';

class _StubExercisesNotifier extends ExercisesNotifier {
  @override
  Future<List<Exercise>> build() async => const [];
}

class _StubDetail extends WorkoutDetailNotifier {
  _StubDetail(this._workout, this.logged);
  final Workout _workout;
  final List<(String, int?)> logged;
  @override
  Future<Workout> build(String workoutId) async => _workout;
  @override
  Future<void> logReps(String setId, int? reps) async => logged.add((setId, reps));
}

class _NoHistory extends FinishedWorkoutsNotifier {
  @override
  Future<List<Workout>> build() async => const [];
}

Workout _workout({required String status, required List<WorkoutSet> sets}) => Workout(
      id: 'w1',
      userId: 'u1',
      title: 'Squat day',
      date: DateTime(2026, 11, 5),
      updatedAt: DateTime(2026, 11, 5),
      workoutGroupId: 'g1',
      status: status,
      startedAt: status == 'not_started' ? null : DateTime(2026, 11, 5, 9),
      pausedAt: status == 'paused' ? DateTime(2026, 11, 5, 9, 30) : null,
      finishedAt: status == 'finished' ? DateTime(2026, 11, 5, 10) : null,
      exercises: [
        WorkoutExercise(
          id: 'we1',
          workoutId: 'w1',
          exerciseId: 'e1',
          exerciseName: 'Back Squat',
          position: 0,
          sets: sets,
        ),
      ],
    );

WorkoutSet _set(String id, {int? actualReps, String weightMode = 'absolute'}) => WorkoutSet(
      id: id,
      workoutExerciseId: 'we1',
      position: 0,
      weightMode: weightMode,
      targetReps: 5,
      absoluteWeightKg: weightMode == 'absolute' ? 100 : null,
      actualReps: actualReps,
    );

/// Bounded pumps: a live session renders a timer, which can keep
/// pumpAndSettle from ever settling.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<List<(String, int?)>> _pumpDetail(WidgetTester tester, Workout workout) async {
  final logged = <(String, int?)>[];
  await tester.pumpWidget(ProviderScope(
    overrides: [
      workoutDetailProvider('w1').overrideWith(() => _StubDetail(workout, logged)),
      oneRepMaxProvider.overrideWith((ref) async => const {}),
      oneRepMaxByNameProvider.overrideWith((ref) async => const {}),
      exercisesProvider.overrideWith(() => _StubExercisesNotifier()),
      finishedWorkoutsProvider.overrideWith(() => _NoHistory()),
    ],
    child: const MaterialApp(home: WorkoutDetailScreen(workoutId: 'w1')),
  ));
  await _settle(tester);
  return logged;
}

String _stepperText(WidgetTester tester) => tester
    .widget<TextField>(
        find.descendant(of: find.byKey(const Key('log_reps_value')), matching: find.byType(TextField)))
    .controller!
    .text;

void main() {
  testWidgets('a live set logs reps with a stepper that starts at the target', (tester) async {
    final logged = await _pumpDetail(tester, _workout(status: 'in_progress', sets: [_set('s1')]));

    await tester.tap(find.byKey(const Key('set_actual_reps_s1')));
    await _settle(tester);
    expect(_stepperText(tester), '5');
    expect(find.text('Clear'), findsNothing);
    expect(logged, isEmpty);

    final minus = find.descendant(of: find.byKey(const Key('log_reps_value')), matching: find.byIcon(Icons.remove));
    await tester.tap(minus);
    await tester.pump();
    await tester.tap(find.text('Save'));
    await _settle(tester);
    expect(logged, [('s1', 4)]);
  });

  testWidgets('a logged set shows what was done and can be cleared', (tester) async {
    final logged = await _pumpDetail(tester, _workout(status: 'paused', sets: [_set('s1', actualReps: 4)]));
    expect(find.text('4 reps done'), findsOneWidget);
    await tester.tap(find.text('4 reps done'));
    await _settle(tester);
    expect(_stepperText(tester), '4');
    await tester.tap(find.text('Clear'));
    await _settle(tester);
    expect(logged, [('s1', null)]);
  });

  testWidgets('a finished session shows logged reps read-only and no Log reps button', (tester) async {
    await _pumpDetail(tester, _workout(status: 'finished', sets: [_set('s1', actualReps: 1)]));
    expect(find.text('1 rep done'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '1 rep done'), findsNothing);
    expect(find.text('Log reps'), findsNothing);
  });

  testWidgets('Log reps is its own button for assistive tech', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpDetail(tester, _workout(status: 'paused', sets: [_set('s1')]));
    final reps = tester.getSemantics(find.text('Log reps'));
    expect(reps.label, 'Log reps');
    expect(reps.flagsCollection.isButton, isTrue);
    expect(tester.getSemantics(find.byType(CheckboxListTile)).label, isNot(contains('Log reps')));
    handle.dispose();
  });

  testWidgets('an open-load set on a phone puts its three log buttons under the set', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pumpDetail(tester, _workout(status: 'paused', sets: [_set('s1', weightMode: 'open')]));
    final tile = tester.getRect(find.byType(CheckboxListTile));
    for (final label in ['Log weight', 'Log reps', 'Log RPE']) {
      expect(tester.getRect(find.text(label)).top, greaterThanOrEqualTo(tile.bottom), reason: label);
    }
  });
}
