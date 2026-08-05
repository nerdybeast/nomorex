import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/core/utils/weight_converter.dart';
import 'package:nomorex/features/exercises/models/exercise.dart';
import 'package:nomorex/features/exercises/providers/exercises_provider.dart';
import 'package:nomorex/features/workouts/utils/parsed_set.dart';
import 'package:nomorex/features/workouts/widgets/set_editor.dart';
import 'package:nomorex/shared/models/editable_set_row.dart';

const _otherExercise = Exercise(id: 'e2', name: 'Front Squat', isPredefined: true);

class _StubExercisesNotifier extends ExercisesNotifier {
  @override
  Future<List<Exercise>> build() async => const [_otherExercise];
}

Widget _wrap(Widget child) => ProviderScope(
      overrides: [
        exercisesProvider.overrideWith(() => _StubExercisesNotifier()),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );

Future<void> _tapStepper(
  WidgetTester tester, {
  required String label,
  required IconData icon,
  int times = 1,
}) async {
  final row = find.ancestor(of: find.text(label), matching: find.byType(Row));
  final button = find.descendant(of: row, matching: find.byIcon(icon));
  for (var i = 0; i < times; i++) {
    await tester.tap(button);
    await tester.pump();
  }
}

void main() {
  testWidgets('Add sets (%) supports a different percentage per set', (tester) async {
    List<ParsedSet>? added;

    await tester.pumpWidget(
      _wrap(SetEditor(
        sets: const [],
        unit: 'kg',
        onAddPercentageSets: (parsed) => added = parsed,
        onAddAbsoluteSets: (_, _, _) {},
        onDeleteSet: (_) {},
      )),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add sets (%)'));
    await tester.pumpAndSettle();

    // Grow from 1 to 3 sets; a %1RM stepper should appear for each.
    await _tapStepper(tester, label: 'Sets', icon: Icons.add_circle_outline, times: 2);
    expect(find.text('Set 1 %1RM'), findsOneWidget);
    expect(find.text('Set 2 %1RM'), findsOneWidget);
    expect(find.text('Set 3 %1RM'), findsOneWidget);

    // Nudge just the second set's percentage up from the 70 default.
    await _tapStepper(tester, label: 'Set 2 %1RM', icon: Icons.add_circle_outline);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(added, isNotNull);
    expect(added!.map((s) => s.targetReps), [1, 1, 1]);
    expect(added!.map((s) => s.percentage), [70, 75, 70]);
    expect(added!.map((s) => s.basisExerciseId), [null, null, null]);
  });

  testWidgets('"Based on" defaults to this exercise and flows through when changed',
      (tester) async {
    List<ParsedSet>? added;

    await tester.pumpWidget(
      _wrap(SetEditor(
        sets: const [],
        unit: 'kg',
        onAddPercentageSets: (parsed) => added = parsed,
        onAddAbsoluteSets: (_, _, _) {},
        onDeleteSet: (_) {},
      )),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add sets (%)'));
    await tester.pumpAndSettle();

    expect(find.text('This exercise'), findsOneWidget);

    await tester.tap(find.text('This exercise'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Front Squat').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(added, isNotNull);
    expect(added!.single.basisExerciseId, 'e2');
  });

  testWidgets('Add sets (weight) collects sets/reps/weight and converts lbs to kg',
      (tester) async {
    int? capturedSets;
    int? capturedReps;
    double? capturedWeightKg;

    await tester.pumpWidget(
      _wrap(SetEditor(
        sets: const [],
        unit: 'lbs',
        onAddPercentageSets: (_) {},
        onAddAbsoluteSets: (sets, reps, weightKg) {
          capturedSets = sets;
          capturedReps = reps;
          capturedWeightKg = weightKg;
        },
        onDeleteSet: (_) {},
      )),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add sets (weight)'));
    await tester.pumpAndSettle();

    await _tapStepper(tester, label: 'Sets', icon: Icons.add_circle_outline);
    await _tapStepper(tester, label: 'Reps', icon: Icons.add_circle_outline, times: 4);
    await _tapStepper(tester, label: 'Weight (lbs)', icon: Icons.add_circle_outline);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(capturedSets, 2);
    expect(capturedReps, 5);
    expect(capturedWeightKg, closeTo(lbsToKg(5), 0.001));
  });

  testWidgets(
      'typing a weight directly and moving focus away commits it, even '
      'without pressing enter', (tester) async {
    double? capturedWeightKg;

    await tester.pumpWidget(
      _wrap(SetEditor(
        sets: const [],
        unit: 'kg',
        onAddPercentageSets: (_) {},
        onAddAbsoluteSets: (_, _, weightKg) => capturedWeightKg = weightKg,
        onDeleteSet: (_) {},
      )),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add sets (weight)'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '0.0'), '102.5');
    // Move focus to another field (e.g. tabbing away) without submitting via
    // enter — a Text tap wouldn't actually shift focus, so target the Reps
    // TextField instead.
    final repsRow = find.ancestor(of: find.text('Reps'), matching: find.byType(Row));
    await tester.tap(find.descendant(of: repsRow, matching: find.byType(TextField)));
    await tester.pump();

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(capturedWeightKg, 102.5);
  });

  testWidgets('sets stepper cannot go below 1', (tester) async {
    await tester.pumpWidget(
      _wrap(SetEditor(
        sets: const [],
        unit: 'kg',
        onAddPercentageSets: (_) {},
        onAddAbsoluteSets: (_, _, _) {},
        onDeleteSet: (_) {},
      )),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add sets (weight)'));
    await tester.pumpAndSettle();

    final row = find.ancestor(of: find.text('Sets'), matching: find.byType(Row));
    final decrement = find.ancestor(
      of: find.descendant(of: row, matching: find.byIcon(Icons.remove_circle_outline)),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(decrement).onPressed, isNull);
  });

  testWidgets('renders "% of <basis>" when a set has a basis exercise', (tester) async {
    await tester.pumpWidget(
      _wrap(SetEditor(
        sets: const [
          EditableSetRow(
            id: 's1',
            weightMode: 'percentage',
            targetReps: 5,
            percentage: 85,
            basisExerciseId: 'e2',
            basisExerciseName: 'Front Squat',
          ),
        ],
        unit: 'kg',
        onAddPercentageSets: (_) {},
        onAddAbsoluteSets: (_, _, _) {},
        onDeleteSet: (_) {},
      )),
    );
    await tester.pumpAndSettle();

    expect(find.text('85% of Front Squat'), findsOneWidget);
  });
}
