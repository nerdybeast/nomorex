import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/core/utils/percent_range.dart';
import 'package:nomorex/core/utils/weight_converter.dart';
import 'package:nomorex/features/exercises/models/exercise.dart';
import 'package:nomorex/features/exercises/providers/exercises_provider.dart';
import 'package:nomorex/features/programs/models/program_set.dart';
import 'package:nomorex/features/workouts/models/workout_set.dart';
import 'package:nomorex/features/workouts/providers/one_rep_max_provider.dart';
import 'package:nomorex/features/workouts/utils/parsed_set.dart';
import 'package:nomorex/features/workouts/utils/set_resolver.dart';
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
}) =>
    SetEditor(
      sets: sets,
      unit: 'kg',
      currentExerciseId: 'e1',
      currentExerciseName: 'Back Squat',
      onAddPercentageSets: onPct ?? (_) {},
      onAddAbsoluteSets: (_) {},
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

Finder _field(String key) =>
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField));

String _stepperText(WidgetTester tester, String key) =>
    tester.widget<TextField>(_field(key)).controller!.text;

Future<void> _openPctDialogWithRange(WidgetTester tester) async {
  await tester.tap(find.text('Add sets (%)'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const Key('set_editor_pct_range_switch')));
  await tester.tap(find.byKey(const Key('set_editor_pct_range_switch')));
  await tester.pumpAndSettle();
}

void main() {
  group('formatPercentTarget', () {
    test('single percentages keep a half percent instead of rounding it away', () {
      expect(formatPercentTarget(70, null), '70%');
      expect(formatPercentTarget(72.5, null), '72.5%');
      expect(formatPercentTarget(null, null), '?%');
    });

    test('ranges, and a range that collapses to one number', () {
      expect(formatPercentTarget(67, 72.5), '67–72.5%');
      expect(formatPercentTarget(80, 85), '80–85%');
      expect(formatPercentTarget(80, 80), '80%');
    });
  });

  group('resolveSetWeightRangeKg', () {
    test('a %1RM range resolves both ends from the same 1RM', () {
      final r = resolveSetWeightRangeKg(
        weightMode: 'percentage',
        percentage: 67,
        percentageMax: 72.5,
        oneRepMaxKg: 200,
      );
      expect(r!.low, closeTo(134, 1e-9));
      expect(r.high, closeTo(145, 1e-9));
    });

    test('a single percentage has no top', () {
      final r = resolveSetWeightRangeKg(weightMode: 'percentage', percentage: 80, oneRepMaxKg: 100);
      expect(r!.low, closeTo(80, 1e-9));
      expect(r.high, isNull);
    });

    test('no 1RM is null, not zero — the same as resolveSetWeightKg', () {
      expect(
        resolveSetWeightRangeKg(weightMode: 'percentage', percentage: 67, percentageMax: 72.5),
        isNull,
      );
    });

    test('an absolute set ignores any percentage range', () {
      final r = resolveSetWeightRangeKg(
        weightMode: 'absolute',
        absoluteWeightKg: 100,
        percentage: 67,
        percentageMax: 72.5,
        oneRepMaxKg: 200,
      );
      expect(r!.low, 100);
      expect(r.high, isNull);
    });
  });

  group('formatResolvedWeightRange', () {
    test('kg, lbs and both', () {
      expect(formatResolvedWeightRange(100, 107.5, 'kg', estimated: false), '100–107.5 kg');
      expect(formatResolvedWeightRange(100, 110, 'lbs', estimated: false), '220.5–242.5 lbs');
      expect(formatResolvedWeightRange(100, 107.5, 'both', estimated: false),
          '220–237 lbs / 100–107.5 kg');
    });

    test('the est. marker applies to the whole range', () {
      expect(formatResolvedWeightRange(134, 145, 'kg', estimated: true), '134–145 kg (est.)');
    });

    test('a single weight, or ends that display the same, show one number', () {
      expect(formatResolvedWeightRange(100, null, 'kg', estimated: true), '100 kg (est.)');
      expect(formatWeightRangeForPreference(100, 100.01, 'kg'), '100 kg');
    });
  });

  group('models and copies', () {
    test('WorkoutSet and ProgramSet read percentage_max into the editable row', () {
      final w = WorkoutSet.fromJson({
        'id': 's1',
        'workout_exercise_id': 'we1',
        'position': 0,
        'target_reps': 7,
        'weight_mode': 'percentage',
        'percentage': 67,
        'percentage_max': 72.5,
      });
      final p = ProgramSet.fromJson({
        'id': 'ps1',
        'program_exercise_id': 'pe1',
        'position': 0,
        'target_reps': 7,
        'weight_mode': 'percentage',
        'percentage': 67,
        'percentage_max': 72.5,
      });
      expect(w.toEditableRow().percentageMax, 72.5);
      expect(p.toEditableRow().percentageMax, 72.5);
    });

  });

  group('SetEditor %1RM range', () {
    testWidgets('the batch gets the range; the top starts 5 above the bottom', (tester) async {
      List<ParsedSet>? added;
      await tester.pumpWidget(_wrap(_editor(onPct: (p) => added = p)));
      await tester.pumpAndSettle();
      await _openPctDialogWithRange(tester);

      expect(find.text('Min %1RM'), findsOneWidget);
      expect(_stepperText(tester, 'set_editor_pct_max'), '75');

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(added!.single.percentage, 70);
      expect(added!.single.percentageMax, 75);
    });

    testWidgets('a half-percent top can be typed (67–72.5%)', (tester) async {
      List<ParsedSet>? added;
      await tester.pumpWidget(_wrap(_editor(onPct: (p) => added = p)));
      await tester.pumpAndSettle();
      await _openPctDialogWithRange(tester);

      await tester.enterText(_field('set_editor_pct'), '67');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.enterText(_field('set_editor_pct_max'), '72.5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(added!.single.percentage, 67);
      expect(added!.single.percentageMax, 72.5);
    });

    testWidgets('raising the bottom past the top drags it along; a collapsed range saves as one',
        (tester) async {
      List<ParsedSet>? added;
      await tester.pumpWidget(_wrap(_editor(onPct: (p) => added = p)));
      await tester.pumpAndSettle();
      await _openPctDialogWithRange(tester);

      await _tapIn(tester, 'set_editor_pct', Icons.add, times: 2); // 80 > 75
      expect(_stepperText(tester, 'set_editor_pct_max'), '80');

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(added!.single.percentage, 80);
      expect(added!.single.percentageMax, isNull);
    });

    testWidgets('typed percentages are held to the bounds the database accepts (#36)',
        (tester) async {
      List<ParsedSet>? added;
      await tester.pumpWidget(_wrap(_editor(onPct: (p) => added = p)));
      await tester.pumpAndSettle();
      await _openPctDialogWithRange(tester);

      await tester.enterText(_field('set_editor_pct'), '0');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(_stepperText(tester, 'set_editor_pct'), '0.5');

      await tester.enterText(_field('set_editor_pct_max'), '900');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(_stepperText(tester, 'set_editor_pct_max'), '200');

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(added!.single.percentage, kMinSetPercentage);
      expect(added!.single.percentageMax, kMaxSetPercentage);
    });

    testWidgets('set rows label ranges and half percents', (tester) async {
      await tester.pumpWidget(_wrap(_editor(sets: const [
        EditableSetRow(id: 'a', weightMode: 'percentage', targetReps: 7, percentage: 67, percentageMax: 72.5),
        EditableSetRow(id: 'b', weightMode: 'percentage', targetReps: 3, percentage: 82.5),
      ])));
      await tester.pumpAndSettle();

      expect(find.text('67–72.5% of 1RM'), findsOneWidget);
      expect(find.text('82.5% of 1RM'), findsOneWidget);
    });
  });
}
