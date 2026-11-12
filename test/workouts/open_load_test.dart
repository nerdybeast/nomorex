import 'package:flutter/material.dart';
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
import 'package:nomorex/features/workouts/utils/parsed_set.dart';
import 'package:nomorex/features/workouts/utils/set_resolver.dart';
import 'package:nomorex/features/workouts/widgets/set_editor.dart';
import 'package:nomorex/shared/models/editable_set_row.dart';
import 'package:nomorex/shared/widgets/set_pr_link.dart';

// Open-load sets (#66): weight_mode = 'open', no prescribed load, the lifter
// picks it on the day.

class _StubExercisesNotifier extends ExercisesNotifier {
  @override
  Future<List<Exercise>> build() async => const [];
}

Widget _wrapEditor(Widget child) => ProviderScope(
      overrides: [
        exercisesProvider.overrideWith(() => _StubExercisesNotifier()),
        oneRepMaxProvider.overrideWith((ref) async => const {}),
        oneRepMaxByNameProvider.overrideWith((ref) async => const {}),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );

SetEditor _editor({
  List<EditableSetRow> sets = const [],
  String unit = 'kg',
  void Function(AbsoluteSetBatch)? onAbs,
}) =>
    SetEditor(
      sets: sets,
      unit: unit,
      currentExerciseId: 'e1',
      currentExerciseName: 'Pull-Up',
      onAddPercentageSets: (_) {},
      onAddAbsoluteSets: onAbs ?? (_) {},
      onDeleteSet: (_) {},
      onReorderSets: (_) {},
    );

Future<void> _tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

class _StubDetail extends WorkoutDetailNotifier {
  _StubDetail(this._workout, this.logged);
  final Workout _workout;
  final List<(String, double?)> logged;
  @override
  Future<Workout> build(String workoutId) async => _workout;
  @override
  Future<void> logWeight(String setId, double? weightKg) async => logged.add((setId, weightKg));
}

class _NoHistory extends FinishedWorkoutsNotifier {
  @override
  Future<List<Workout>> build() async => const [];
}

WorkoutSet _openSet(String id, {double? actualWeightKg, int position = 0}) => WorkoutSet(
      id: id,
      workoutExerciseId: 'we1',
      position: position,
      weightMode: 'open',
      targetReps: 7,
      targetRepsMax: 9,
      rpeMin: 6,
      rpeMax: 7,
      actualWeightKg: actualWeightKg,
    );

Workout _workout({required String status, required List<WorkoutSet> sets}) => Workout(
      id: 'w1',
      userId: 'u1',
      title: 'Pull day',
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
          exerciseName: 'Pull-Up',
          position: 0,
          sets: sets,
        ),
      ],
    );

/// Bounded pumps: a live session renders a timer, which can keep
/// pumpAndSettle from ever settling.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<List<(String, double?)>> _pumpDetail(
  WidgetTester tester,
  Workout workout, {
  String unit = 'kg',
}) async {
  final logged = <(String, double?)>[];
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

void main() {
  group('resolver', () {
    test('an open set resolves to no weight, whatever the 1RM', () {
      expect(isOpenLoad('open'), isTrue);
      expect(isOpenLoad('absolute'), isFalse);
      expect(isOpenLoad('percentage'), isFalse);
      expect(
        resolveSetWeightKg(weightMode: 'open', percentage: 80, oneRepMaxKg: 100),
        isNull,
      );
      expect(
        resolveSetWeightRangeKg(weightMode: 'open', oneRepMaxKg: 100),
        isNull,
      );
    });
  });

  group('model and copies', () {
    test('fromJson reads an open set with no load', () {
      final s = WorkoutSet.fromJson({
        'id': 's1',
        'workout_exercise_id': 'we1',
        'position': 0,
        'weight_mode': 'open',
        'target_reps': 7,
        'percentage': null,
        'absolute_weight_kg': null,
      });
      expect(s.weightMode, 'open');
      expect(s.absoluteWeightKg, isNull);
      expect(s.toEditableRow().weightMode, 'open');
    });

  });

  group('SetEditor', () {
    testWidgets('"No set load" hides the weight and adds an open batch', (tester) async {
      AbsoluteSetBatch? batch;
      await tester.pumpWidget(_wrapEditor(_editor(onAbs: (b) => batch = b)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add sets (weight)'));
      await tester.pumpAndSettle();

      expect(find.text('Weight (kg)'), findsOneWidget);
      await _tapKey(tester, 'set_editor_open_load_switch');
      expect(find.text('Weight (kg)'), findsNothing);
      expect(find.text('Unit'), findsNothing);

      // RPE is still on offer: "3 x 7-9, %1RM NA, RPE 6-7".
      await _tapKey(tester, 'set_editor_rpe_switch');
      await tester.tap(find.byKey(const Key('set_editor_add')));
      await tester.pumpAndSettle();

      expect(batch, isNotNull);
      expect(batch!.weightKg, isNull);
      expect(batch!.rpeMin, 7);
    });

    testWidgets('switching it back off adds a normal weighted batch', (tester) async {
      AbsoluteSetBatch? batch;
      await tester.pumpWidget(_wrapEditor(_editor(unit: 'lbs', onAbs: (b) => batch = b)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add sets (weight)'));
      await tester.pumpAndSettle();

      await _tapKey(tester, 'set_editor_open_load_switch');
      await _tapKey(tester, 'set_editor_open_load_switch');
      final plus = find.descendant(
        of: find.ancestor(of: find.text('Weight (lbs)'), matching: find.byType(Row)),
        matching: find.byIcon(Icons.add),
      );
      await tester.tap(plus);
      await tester.pump();
      await tester.tap(find.byKey(const Key('set_editor_add')));
      await tester.pumpAndSettle();

      expect(batch!.weightKg, closeTo(lbsToKg(5), 0.001));
    });

    testWidgets('an open set row reads "Choose load", not "0 kg"', (tester) async {
      await tester.pumpWidget(_wrapEditor(_editor(sets: const [
        EditableSetRow(
          id: 's1',
          weightMode: 'open',
          targetReps: 7,
          targetRepsMax: 9,
          rpeMin: 6,
          rpeMax: 7,
        ),
      ])));
      await tester.pumpAndSettle();

      expect(find.text('Choose load · RPE 6–7'), findsOneWidget);
      expect(find.textContaining('kg'), findsNothing);
    });
  });

  group('workout detail', () {
    testWidgets('an open set says "choose load" and offers no Add-PR shortcut', (tester) async {
      await _pumpDetail(tester, _workout(status: 'not_started', sets: [_openSet('s1')]));

      expect(find.text('choose load · RPE 6–7'), findsOneWidget);
      expect(find.byType(SetPrLink), findsNothing);
      expect(find.textContaining('0 kg'), findsNothing);
      // Not live: nothing to log yet.
      expect(find.text('Log weight'), findsNothing);
    });

    testWidgets('a live open set logs the weight used, starting empty', (tester) async {
      final logged = await _pumpDetail(tester, _workout(status: 'paused', sets: [_openSet('s1')]));

      await tester.tap(find.byKey(const Key('set_actual_weight_s1')));
      await _settle(tester);
      expect(find.text('Weight (kg)'), findsOneWidget);
      expect(find.text('Clear'), findsNothing);

      final plus = find.descendant(
        of: find.byKey(const Key('log_weight_value')),
        matching: find.byIcon(Icons.add),
      );
      for (var i = 0; i < 4; i++) {
        await tester.tap(plus);
        await tester.pump();
      }
      await tester.tap(find.text('Save'));
      await _settle(tester);

      expect(logged, [('s1', 10.0)]);
    });

    testWidgets('a lbs user logs in lbs and it is saved in kg', (tester) async {
      final logged = await _pumpDetail(
        tester,
        _workout(status: 'paused', sets: [_openSet('s1')]),
        unit: 'lbs',
      );
      await tester.tap(find.text('Log weight'));
      await _settle(tester);
      final plus = find.descendant(
        of: find.byKey(const Key('log_weight_value')),
        matching: find.byIcon(Icons.add),
      );
      await tester.tap(plus);
      await tester.pump();
      await tester.tap(find.text('Save'));
      await _settle(tester);

      expect(logged.single.$2, closeTo(lbsToKg(5), 0.001));
    });

    testWidgets('a logged weight shows on the button and can be cleared', (tester) async {
      final logged = await _pumpDetail(
        tester,
        _workout(status: 'paused', sets: [_openSet('s1', actualWeightKg: 20)]),
      );
      expect(find.text('20 kg'), findsOneWidget);
      await tester.tap(find.text('20 kg'));
      await _settle(tester);
      await tester.tap(find.text('Clear'));
      await _settle(tester);
      expect(logged, [('s1', null)]);
    });

    testWidgets('a finished session shows the logged weight read-only', (tester) async {
      await _pumpDetail(
        tester,
        _workout(status: 'finished', sets: [
          _openSet('s1', actualWeightKg: 20),
          _openSet('s2', position: 1),
        ]),
      );
      expect(find.text('20 kg'), findsOneWidget);
      expect(find.widgetWithText(TextButton, '20 kg'), findsNothing);
      expect(find.text('Log weight'), findsNothing);
    });

    testWidgets('sets with a prescribed load never offer Log weight', (tester) async {
      await _pumpDetail(
        tester,
        _workout(status: 'paused', sets: const [
          WorkoutSet(
            id: 's1',
            workoutExerciseId: 'we1',
            position: 0,
            weightMode: 'absolute',
            targetReps: 5,
            absoluteWeightKg: 100,
          ),
        ]),
      );
      expect(find.text('Log weight'), findsNothing);
    });

    testWidgets('Log weight is its own button for assistive tech', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpDetail(tester, _workout(status: 'paused', sets: [_openSet('s1')]));

      final button = tester.getSemantics(find.text('Log weight'));
      expect(button.label, 'Log weight');
      expect(button.flagsCollection.isButton, isTrue);
      final checkbox = tester.getSemantics(find.byType(CheckboxListTile));
      expect(checkbox.label, isNot(contains('Log weight')));
      handle.dispose();
    });
  });
}
