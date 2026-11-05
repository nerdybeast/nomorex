import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/core/utils/rep_range.dart';
import 'package:nomorex/features/exercises/models/exercise.dart';
import 'package:nomorex/features/exercises/providers/exercises_provider.dart';
import 'package:nomorex/features/programs/models/program_set.dart';
import 'package:nomorex/features/workouts/models/workout_set.dart';
import 'package:nomorex/features/workouts/providers/one_rep_max_provider.dart';
import 'package:nomorex/features/workouts/utils/parsed_set.dart';
import 'package:nomorex/features/workouts/utils/workout_copier.dart';
import 'package:nomorex/features/workouts/widgets/set_editor.dart';
import 'package:nomorex/shared/models/editable_set_row.dart';

class _StubExercisesNotifier extends ExercisesNotifier {
  @override
  Future<List<Exercise>> build() async => const [];
}

Widget _wrap(Widget child) => ProviderScope(
      overrides: [
        exercisesProvider.overrideWith(() => _StubExercisesNotifier()),
        oneRepMaxProvider.overrideWith((ref) async => const {}),
        oneRepMaxByNameProvider.overrideWith((ref) async => const {}),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );

SetEditor _editor({
  List<EditableSetRow> sets = const [],
  void Function(List<ParsedSet>)? onPct,
  void Function(AbsoluteSetBatch)? onAbs,
}) =>
    SetEditor(
      sets: sets,
      unit: 'kg',
      currentExerciseId: 'e1',
      currentExerciseName: 'Back Squat',
      onAddPercentageSets: onPct ?? (_) {},
      onAddAbsoluteSets: onAbs ?? (_) {},
      onDeleteSet: (_) {},
      onReorderSets: (_) {},
    );

Future<void> _tapIn(WidgetTester tester, String key, IconData icon, {int times = 1}) async {
  final button = find.descendant(of: find.byKey(Key(key)), matching: find.byIcon(icon));
  for (var i = 0; i < times; i++) {
    await tester.tap(button);
    await tester.pump();
  }
}

String _stepperText(WidgetTester tester, String key) => tester
    .widget<TextField>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField)))
    .controller!
    .text;

void main() {
  group('formatTargetReps', () {
    test('single counts', () {
      expect(formatTargetReps(5, null), '5 reps');
      expect(formatTargetReps(1, null), '1 rep');
      expect(formatTargetReps(null, null), '- reps');
    });

    test('ranges, and a range that collapses to one number', () {
      expect(formatTargetReps(7, 9), '7–9 reps');
      expect(formatTargetReps(1, 3), '1–3 reps');
      expect(formatTargetReps(5, 5), '5 reps');
    });
  });

  group('models', () {
    test('WorkoutSet reads target_reps_max and carries it to the editable row', () {
      final s = WorkoutSet.fromJson({
        'id': 's1',
        'workout_exercise_id': 'we1',
        'position': 0,
        'target_reps': 7,
        'target_reps_max': 9,
        'weight_mode': 'percentage',
        'percentage': 70,
      });
      expect(s.targetRepsMax, 9);
      expect(s.toEditableRow().targetRepsMax, 9);
    });

    test('ProgramSet reads target_reps_max and carries it to the editable row', () {
      final s = ProgramSet.fromJson({
        'id': 'ps1',
        'program_exercise_id': 'pe1',
        'position': 0,
        'target_reps': 1,
        'target_reps_max': 3,
        'weight_mode': 'percentage',
        'percentage': 85,
      });
      expect(s.targetRepsMax, 3);
      expect(s.toEditableRow().targetRepsMax, 3);
    });

    test('a row without target_reps_max is a single rep count', () {
      final s = WorkoutSet.fromJson({
        'id': 's1',
        'workout_exercise_id': 'we1',
        'position': 0,
        'target_reps': 5,
        'weight_mode': 'absolute',
        'absolute_weight_kg': 100,
      });
      expect(s.targetRepsMax, isNull);
    });
  });

  group('copiedSetRow', () {
    const ranged = WorkoutSet(
      id: 's1',
      workoutExerciseId: 'we1',
      position: 2,
      weightMode: 'absolute',
      targetReps: 7,
      targetRepsMax: 9,
      absoluteWeightKg: 100,
      completed: true,
      actualReps: 8,
      actualWeightKg: 100,
    );

    test('carries the rep range but no logged results', () {
      final row = copiedSetRow(ranged, workoutExerciseId: 'new', userId: 'u1');
      expect(row['target_reps'], 7);
      expect(row['target_reps_max'], 9);
      expect(row['workout_exercise_id'], 'new');
      expect(row.containsKey('completed'), isFalse);
      expect(row.containsKey('actual_reps'), isFalse);
      expect(row.containsKey('actual_weight_kg'), isFalse);
    });

    test('omits target_reps_max for a single rep count', () {
      const single = WorkoutSet(
        id: 's1',
        workoutExerciseId: 'we1',
        position: 0,
        weightMode: 'absolute',
        targetReps: 5,
        absoluteWeightKg: 100,
      );
      final row = copiedSetRow(single, workoutExerciseId: 'new', userId: 'u1');
      expect(row.containsKey('target_reps_max'), isFalse);
    });
  });

  group('SetEditor rep range', () {
    testWidgets('Add sets (%) passes the range top on every set in the batch', (tester) async {
      List<ParsedSet>? added;
      await tester.pumpWidget(_wrap(_editor(onPct: (p) => added = p)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add sets (%)'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('set_editor_reps_max')), findsNothing);
      await tester.tap(find.byKey(const Key('set_editor_rep_range_switch')));
      await tester.pumpAndSettle();

      // Turning the range on starts two above the minimum (1 -> 1 to 3).
      expect(find.text('Min reps'), findsOneWidget);
      expect(_stepperText(tester, 'set_editor_reps_max'), '3');

      await _tapIn(tester, 'set_editor_reps', Icons.add, times: 6); // 7
      await _tapIn(tester, 'set_editor_reps_max', Icons.add, times: 2); // 9
      // Sets stepper is the first "Sets" row.
      final setsPlus = find.descendant(
        of: find.ancestor(of: find.text('Sets'), matching: find.byType(Row)),
        matching: find.byIcon(Icons.add),
      );
      await tester.tap(setsPlus.first);
      await tester.pump();

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(added!.map((s) => s.targetReps), [7, 7]);
      expect(added!.map((s) => s.targetRepsMax), [9, 9]);
    });

    testWidgets('raising the minimum past the top drags the top along', (tester) async {
      await tester.pumpWidget(_wrap(_editor()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add sets (%)'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('set_editor_rep_range_switch')));
      await tester.pumpAndSettle();

      await _tapIn(tester, 'set_editor_reps', Icons.add, times: 4); // 5 > 3
      expect(_stepperText(tester, 'set_editor_reps'), '5');
      expect(_stepperText(tester, 'set_editor_reps_max'), '5');
    });

    testWidgets('a range narrowed to one number is saved as a single count', (tester) async {
      List<ParsedSet>? added;
      await tester.pumpWidget(_wrap(_editor(onPct: (p) => added = p)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add sets (%)'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('set_editor_rep_range_switch')));
      await tester.pumpAndSettle();
      await _tapIn(tester, 'set_editor_reps_max', Icons.remove, times: 2); // 1 to 1

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(added!.single.targetReps, 1);
      expect(added!.single.targetRepsMax, isNull);
    });

    testWidgets('Add sets (weight) passes the range top, and null with the range off', (tester) async {
      final calls = <int?>[];
      await tester.pumpWidget(_wrap(_editor(onAbs: (b) => calls.add(b.repsMax))));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add sets (weight)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add sets (weight)'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('set_editor_rep_range_switch')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(calls, [null, 3]);
    });

    testWidgets('set rows label ranges and single counts', (tester) async {
      await tester.pumpWidget(_wrap(_editor(sets: const [
        EditableSetRow(id: 'a', weightMode: 'percentage', targetReps: 7, targetRepsMax: 9, percentage: 70),
        EditableSetRow(id: 'b', weightMode: 'absolute', targetReps: 5, absoluteWeightKg: 100),
      ])));
      await tester.pumpAndSettle();

      expect(find.text('7–9 reps'), findsOneWidget);
      expect(find.text('5 reps'), findsOneWidget);
    });
  });
}
