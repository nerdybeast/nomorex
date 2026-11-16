import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/core/utils/weight_converter.dart';
import 'package:nomorex/features/exercises/models/exercise.dart';
import 'package:nomorex/features/exercises/providers/exercises_provider.dart';
import 'package:nomorex/features/profile/providers/profile_provider.dart';
import 'package:nomorex/features/workouts/models/workout.dart';
import 'package:nomorex/features/workouts/models/workout_exercise.dart';
import 'package:nomorex/features/workouts/models/workout_set.dart';
import 'package:nomorex/features/workouts/providers/finished_workouts_provider.dart';
import 'package:nomorex/features/workouts/providers/one_rep_max_provider.dart';
import 'package:nomorex/features/workouts/providers/workout_detail_provider.dart';
import 'package:nomorex/features/workouts/screens/workout_detail_screen.dart';

/// One `logSet` call as the stub records it.
typedef _Logged = ({String setId, int? reps, double? rpe, double? weightKg, bool complete});

class _StubExercisesNotifier extends ExercisesNotifier {
  @override
  Future<List<Exercise>> build() async => const [];
}

class _StubDetail extends WorkoutDetailNotifier {
  _StubDetail(this._workout, this.logged);
  final Workout _workout;
  final List<_Logged> logged;
  @override
  Future<Workout> build(String workoutId) async => _workout;
  @override
  Future<void> logSet(
    String setId, {
    required int? reps,
    required double? rpe,
    double? weightKg,
    bool complete = true,
  }) async =>
      logged.add((setId: setId, reps: reps, rpe: rpe, weightKg: weightKg, complete: complete));
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
        WorkoutExercise(id: 'we1', workoutId: 'w1', exerciseId: 'e1', exerciseName: 'Back Squat', position: 0, sets: sets),
      ],
    );

WorkoutSet _set(
  String id, {
  int position = 0,
  String weightMode = 'absolute',
  double? rpeMin,
  int? actualReps,
  double? actualRpe,
  double? actualWeightKg,
  bool completed = false,
}) =>
    WorkoutSet(
      id: id,
      workoutExerciseId: 'we1',
      position: position,
      weightMode: weightMode,
      targetReps: 5,
      absoluteWeightKg: weightMode == 'absolute' ? 100 : null,
      rpeMin: rpeMin,
      actualReps: actualReps,
      actualRpe: actualRpe,
      actualWeightKg: actualWeightKg,
      completed: completed,
    );

/// Bounded pumps: a live session renders a timer, which can keep
/// pumpAndSettle from ever settling.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<List<_Logged>> _pumpDetail(WidgetTester tester, Workout workout, {String unit = 'kg'}) async {
  final logged = <_Logged>[];
  await tester.pumpWidget(ProviderScope(
    overrides: [
      workoutDetailProvider('w1').overrideWith(() => _StubDetail(workout, logged)),
      oneRepMaxProvider.overrideWith((ref) async => const {}),
      oneRepMaxByNameProvider.overrideWith((ref) async => const {}),
      exercisesProvider.overrideWith(() => _StubExercisesNotifier()),
      finishedWorkoutsProvider.overrideWith(() => _NoHistory()),
      unitPreferenceProvider.overrideWithValue(unit),
    ],
    child: const MaterialApp(home: WorkoutDetailScreen(workoutId: 'w1')),
  ));
  await _settle(tester);
  return logged;
}

Future<void> _openLog(WidgetTester tester, String setId) async {
  final chip = find.byKey(ValueKey('set_log_$setId'));
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await _settle(tester);
}

String _stepperText(WidgetTester tester, String key) => tester
    .widget<TextField>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField)))
    .controller!
    .text;

Future<void> _tapIn(WidgetTester tester, String key, IconData icon, {int times = 1}) async {
  final button = find.descendant(of: find.byKey(Key(key)), matching: find.byIcon(icon));
  await tester.ensureVisible(button);
  for (var i = 0; i < times; i++) {
    await tester.tap(button);
    await tester.pump();
  }
}

Future<void> _save(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('log_set_save')));
  await tester.tap(find.byKey(const Key('log_set_save')));
  await _settle(tester);
}

void main() {
  testWidgets('a live set offers "Log"; reps start at the target and saving marks the set done', (tester) async {
    final logged = await _pumpDetail(tester, _workout(status: 'in_progress', sets: [_set('s1')]));

    expect(find.text('Log'), findsOneWidget);
    await _openLog(tester, 's1');
    expect(find.text('Log set 1'), findsOneWidget);
    expect(_stepperText(tester, 'log_set_reps'), '5');
    expect(find.text('Clear log'), findsNothing);
    expect(find.text('Save and mark done'), findsOneWidget);
    expect(logged, isEmpty, reason: 'opening the sheet saves nothing');

    await _tapIn(tester, 'log_set_reps', Icons.remove);
    await _save(tester);
    expect(logged, [(setId: 's1', reps: 4, rpe: null, weightKg: null, complete: true)]);
  });

  testWidgets('RPE is added on demand, starting at the target', (tester) async {
    final logged = await _pumpDetail(tester, _workout(status: 'paused', sets: [_set('s1', rpeMin: 6)]));

    await _openLog(tester, 's1');
    expect(find.byKey(const Key('log_set_rpe')), findsNothing);
    await tester.tap(find.byKey(const Key('log_set_add_rpe')));
    await tester.pump();
    expect(_stepperText(tester, 'log_set_rpe'), '6');
    await _tapIn(tester, 'log_set_rpe', Icons.add);
    await _save(tester);
    expect(logged.single.rpe, 6.5);
    expect(logged.single.reps, 5);
  });

  testWidgets('with no target RPE, Add RPE starts at a neutral 7', (tester) async {
    await _pumpDetail(tester, _workout(status: 'paused', sets: [_set('s1')]));
    await _openLog(tester, 's1');
    await tester.tap(find.byKey(const Key('log_set_add_rpe')));
    await tester.pump();
    expect(_stepperText(tester, 'log_set_rpe'), '7');
  });

  testWidgets('closing the sheet logs nothing', (tester) async {
    final logged = await _pumpDetail(tester, _workout(status: 'paused', sets: [_set('s1')]));
    await _openLog(tester, 's1');
    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    expect(logged, isEmpty);
  });

  testWidgets('a logged set shows what was done on the chip and can be cleared without un-ticking it',
      (tester) async {
    final logged = await _pumpDetail(
      tester,
      _workout(status: 'paused', sets: [_set('s1', actualReps: 4, actualRpe: 8, completed: true)]),
    );

    expect(find.text('4/5 · RPE 8'), findsOneWidget);
    await _openLog(tester, 's1');
    expect(_stepperText(tester, 'log_set_reps'), '4');
    expect(_stepperText(tester, 'log_set_rpe'), '8');
    expect(find.text('Save'), findsOneWidget, reason: 'already done, so Save, not "and mark done"');

    await tester.tap(find.byKey(const Key('log_set_clear')));
    await _settle(tester);
    expect(logged, [(setId: 's1', reps: null, rpe: null, weightKg: null, complete: false)]);
  });

  testWidgets('a finished session shows logged values read-only, and nothing for unlogged sets', (tester) async {
    await _pumpDetail(
      tester,
      _workout(status: 'finished', sets: [_set('s1', actualReps: 5, actualRpe: 8.5), _set('s2', position: 1)]),
    );
    expect(find.text('5/5 · RPE 8.5'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '5/5 · RPE 8.5'), findsNothing);
    expect(find.byKey(const ValueKey('set_log_s2')), findsNothing);
    expect(find.text('Log'), findsNothing);
  });

  testWidgets('a session that has not started offers no log', (tester) async {
    await _pumpDetail(tester, _workout(status: 'not_started', sets: [_set('s1')]));
    expect(find.text('Log'), findsNothing);
  });

  group('open load', () {
    testWidgets('the sheet logs the weight used, starting empty', (tester) async {
      final logged = await _pumpDetail(tester, _workout(status: 'paused', sets: [_set('s1', weightMode: 'open')]));

      await _openLog(tester, 's1');
      expect(find.text('Weight (kg)'), findsOneWidget);
      expect(_stepperText(tester, 'log_set_weight'), '0');
      await _tapIn(tester, 'log_set_weight', Icons.add, times: 4);
      await _save(tester);
      expect(logged.single.weightKg, 10.0);
    });

    testWidgets('a typed weight is saved without pressing Done', (tester) async {
      // iOS's number pad has no Done key: the user types and taps Save.
      final logged = await _pumpDetail(tester, _workout(status: 'paused', sets: [_set('s1', weightMode: 'open')]));
      await _openLog(tester, 's1');
      await tester.enterText(
        find.descendant(of: find.byKey(const Key('log_set_weight')), matching: find.byType(TextField)),
        '100',
      );
      await tester.pump();
      await _save(tester);
      expect(logged.single.weightKg, 100.0);
    });

    testWidgets('a lbs user logs in lbs and it is saved in kg', (tester) async {
      final logged = await _pumpDetail(
        tester,
        _workout(status: 'paused', sets: [_set('s1', weightMode: 'open')]),
        unit: 'lbs',
      );
      await _openLog(tester, 's1');
      expect(find.text('Weight (lbs)'), findsOneWidget);
      await _tapIn(tester, 'log_set_weight', Icons.add);
      await _save(tester);
      expect(logged.single.weightKg, closeTo(lbsToKg(5), 0.001));
    });

    testWidgets('a logged weight shows on the chip', (tester) async {
      await _pumpDetail(tester, _workout(status: 'paused', sets: [_set('s1', weightMode: 'open', actualWeightKg: 20)]));
      expect(find.text('20 kg'), findsOneWidget);
    });

    testWidgets('a set with a prescribed load never asks for a weight', (tester) async {
      await _pumpDetail(tester, _workout(status: 'paused', sets: [_set('s1')]));
      await _openLog(tester, 's1');
      expect(find.byKey(const Key('log_set_weight')), findsNothing);
    });
  });

  testWidgets('the log chip and the checkbox are separate controls named for the set', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpDetail(tester, _workout(status: 'paused', sets: [_set('s1')]));

    final chip = tester.getSemantics(find.byKey(const ValueKey('set_log_s1')));
    expect(chip.label, 'Log set 1');
    expect(chip.flagsCollection.isButton, isTrue);
    final checkbox = tester.getSemantics(find.byType(Checkbox));
    expect(checkbox.label, contains('Done: set 1'));
    expect(checkbox.label, isNot(contains('Log')));
    handle.dispose();
  });

  testWidgets('on a phone the reps × load line keeps its own line and the chip sits under it', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pumpDetail(tester, _workout(status: 'paused', sets: [_set('s1', weightMode: 'open', rpeMin: 7)]));

    expect(tester.takeException(), isNull);
    final main = tester.getRect(find.byKey(const ValueKey('set_main_s1')));
    final chip = tester.getRect(find.byKey(const ValueKey('set_log_s1')));
    expect(chip.top, greaterThanOrEqualTo(main.bottom - 1));
  });

  testWidgets('on a wide screen the chip ends the main line instead', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pumpDetail(tester, _workout(status: 'paused', sets: [_set('s1')]));

    final main = tester.getCenter(find.byKey(const ValueKey('set_main_s1')));
    final chip = tester.getCenter(find.byKey(const ValueKey('set_log_s1')));
    expect((chip.dy - main.dy).abs(), lessThan(6));
    expect(chip.dx, greaterThan(main.dx));
  });

  testWidgets('with RPE added, its stepper lines up with the Reps stepper and its ✕ sits by the label',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pumpDetail(tester, _workout(status: 'paused', sets: [_set('s1')]));
    await _openLog(tester, 's1');
    await tester.tap(find.byKey(const Key('log_set_add_rpe')));
    await tester.pump();

    Rect plus(String key) =>
        tester.getRect(find.descendant(of: find.byKey(Key(key)), matching: find.byIcon(Icons.add)));
    expect(plus('log_set_rpe').right, plus('log_set_reps').right);
    expect(tester.getRect(find.byKey(const Key('log_set_remove_rpe'))).right,
        lessThan(tester.getRect(find.descendant(of: find.byKey(const Key('log_set_rpe')), matching: find.byIcon(Icons.remove))).left));

    await tester.tap(find.byKey(const Key('log_set_remove_rpe')));
    await tester.pump();
    expect(find.byKey(const Key('log_set_rpe')), findsNothing);
    expect(find.byKey(const Key('log_set_add_rpe')), findsOneWidget);
  });
}
