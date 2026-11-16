import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/core/utils/rpe.dart';
import 'package:nomorex/features/exercises/models/exercise.dart';
import 'package:nomorex/features/exercises/providers/exercises_provider.dart';
import 'package:nomorex/features/programs/models/program_set.dart';
import 'package:nomorex/features/workouts/models/workout_set.dart';
import 'package:nomorex/features/workouts/providers/one_rep_max_provider.dart';
import 'package:nomorex/features/workouts/utils/parsed_set.dart';
import 'package:nomorex/features/workouts/widgets/set_editor.dart';
import 'package:nomorex/shared/models/editable_set_row.dart';
import 'package:nomorex/shared/widgets/number_stepper_field.dart';

// ---------------------------------------------------------------------------
// Harnesses
// ---------------------------------------------------------------------------

class _StubExercisesNotifier extends ExercisesNotifier {
  @override
  Future<List<Exercise>> build() async => const [];
}

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(ProviderScope(
      overrides: [
        exercisesProvider.overrideWith(() => _StubExercisesNotifier()),
        oneRepMaxProvider.overrideWith((ref) async => const {}),
        oneRepMaxByNameProvider.overrideWith((ref) async => const {}),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    ));

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
      onAddPercentageSets: (x) async => (onPct ?? (_) {})(x),
      onAddAbsoluteSets: (x) async => (onAbs ?? (_) {})(x),
      onReplaceGroup: (_, _, _) async {},
      onReorderSets: (_) async {},
    );

Future<void> _tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _tapIn(WidgetTester tester, String key, IconData icon, {int times = 1}) async {
  final button = find.descendant(of: find.byKey(Key(key)), matching: find.byIcon(icon));
  await tester.ensureVisible(button);
  for (var i = 0; i < times; i++) {
    await tester.tap(button);
    await tester.pump();
  }
}

String _stepperText(WidgetTester tester, String key) => tester
    .widget<TextField>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField)))
    .controller!
    .text;


// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('formatting', () {
    test('formatRpe trims whole numbers and keeps half steps', () {
      expect(formatRpe(8), '8');
      expect(formatRpe(7.5), '7.5');
    });

    test('formatRpeTarget: none, single, range, collapsed range', () {
      expect(formatRpeTarget(null, null), isNull);
      expect(formatRpeTarget(8, null), 'RPE 8');
      expect(formatRpeTarget(6, 7), 'RPE 6–7');
      expect(formatRpeTarget(8.5, 8.5), 'RPE 8.5');
    });
  });

  group('models and copies', () {
    test('WorkoutSet reads target and logged RPE; ProgramSet reads the target', () {
      final w = WorkoutSet.fromJson({
        'id': 's1',
        'workout_exercise_id': 'we1',
        'position': 0,
        'weight_mode': 'absolute',
        'absolute_weight_kg': 100,
        'rpe_min': 6,
        'rpe_max': 7,
        'actual_rpe': 7.5,
      });
      expect((w.rpeMin, w.rpeMax, w.actualRpe), (6.0, 7.0, 7.5));
      expect(w.toEditableRow().rpeMax, 7);

      final p = ProgramSet.fromJson({
        'id': 'ps1',
        'program_exercise_id': 'pe1',
        'position': 0,
        'weight_mode': 'absolute',
        'absolute_weight_kg': 100,
        'rpe_min': 8,
      });
      expect((p.rpeMin, p.rpeMax), (8.0, null));
    });

  });

  group('NumberStepperField max', () {
    testWidgets('+ is disabled at the ceiling and typed values are clamped', (tester) async {
      double? changed;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NumberStepperField(
            label: 'RPE',
            value: 10,
            min: 1,
            max: 10,
            step: 0.5,
            decimals: 1,
            onChanged: (v) => changed = v,
          ),
        ),
      ));
      final plus = tester.widget<IconButton>(
          find.ancestor(of: find.byIcon(Icons.add), matching: find.byType(IconButton)));
      expect(plus.onPressed, isNull);

      await tester.enterText(find.byType(TextField), '12');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(changed, 10);
    });
  });

  group('SetEditor target RPE', () {
    testWidgets('off by default: a batch has no RPE', (tester) async {
      List<ParsedSet>? added;
      await _pump(tester, _editor(onPct: (p) => added = p));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add sets (%)'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('set_editor_rpe')), findsNothing);
      await tester.tap(find.byKey(const Key('set_editor_add')));
      await tester.pumpAndSettle();
      expect(added!.single.rpeMin, isNull);
      expect(added!.single.rpeMax, isNull);
    });

    testWidgets('Add sets (%): RPE starts at 7, a range starts one above', (tester) async {
      List<ParsedSet>? added;
      await _pump(tester, _editor(onPct: (p) => added = p));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add sets (%)'));
      await tester.pumpAndSettle();

      await _tapKey(tester, 'set_editor_rpe_switch');
      expect(_stepperText(tester, 'set_editor_rpe'), '7');
      await _tapIn(tester, 'set_editor_rpe', Icons.remove); // 6.5 — half steps
      expect(_stepperText(tester, 'set_editor_rpe'), '6.5');
      await _tapKey(tester, 'set_editor_rpe_range_switch');
      expect(_stepperText(tester, 'set_editor_rpe_max'), '7.5');

      await tester.tap(find.byKey(const Key('set_editor_add')));
      await tester.pumpAndSettle();
      expect(added!.single.rpeMin, 6.5);
      expect(added!.single.rpeMax, 7.5);
    });

    testWidgets('Add sets (weight) passes the RPE in its batch', (tester) async {
      AbsoluteSetBatch? batch;
      await _pump(tester, _editor(onAbs: (b) => batch = b));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add sets (weight)'));
      await tester.pumpAndSettle();

      await _tapKey(tester, 'set_editor_rpe_switch');
      await _tapIn(tester, 'set_editor_rpe', Icons.add, times: 2); // 8
      await tester.tap(find.byKey(const Key('set_editor_add')));
      await tester.pumpAndSettle();
      expect(batch!.rpeMin, 8);
      expect(batch!.rpeMax, isNull);
    });

    testWidgets('the RPE range never starts or goes past 10', (tester) async {
      List<ParsedSet>? added;
      await _pump(tester, _editor(onPct: (p) => added = p));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add sets (%)'));
      await tester.pumpAndSettle();

      await _tapKey(tester, 'set_editor_rpe_switch');
      await _tapIn(tester, 'set_editor_rpe', Icons.add, times: 5); // 9.5
      await _tapKey(tester, 'set_editor_rpe_range_switch');
      expect(_stepperText(tester, 'set_editor_rpe_max'), '10');

      await tester.tap(find.byKey(const Key('set_editor_add')));
      await tester.pumpAndSettle();
      expect(added!.single.rpeMin, 9.5);
      expect(added!.single.rpeMax, 10);
    });

    testWidgets('set rows show the RPE target', (tester) async {
      await _pump(tester, _editor(sets: const [
        EditableSetRow(
            id: 'a', weightMode: 'percentage', targetReps: 7, percentage: 70, rpeMin: 6, rpeMax: 7),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('70% of 1RM · RPE 6–7'), findsOneWidget);
    });
  });
}
