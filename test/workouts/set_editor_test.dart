import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/core/utils/weight_converter.dart';
import 'package:nomorex/features/workouts/models/workout_exercise.dart';
import 'package:nomorex/features/workouts/utils/parsed_set.dart';
import 'package:nomorex/features/workouts/widgets/set_editor.dart';

const _exercise = WorkoutExercise(
  id: 'we1',
  workoutId: 'w1',
  exerciseId: 'e1',
  exerciseName: 'Back Squat',
  position: 0,
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
      MaterialApp(
        home: Scaffold(
          body: SetEditor(
            exercise: _exercise,
            unit: 'kg',
            onAddPercentageSets: (parsed) => added = parsed,
            onAddAbsoluteSets: (_, _, _) {},
            onDeleteSet: (_) {},
          ),
        ),
      ),
    );

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
  });

  testWidgets('Add sets (weight) collects sets/reps/weight and converts lbs to kg',
      (tester) async {
    int? capturedSets;
    int? capturedReps;
    double? capturedWeightKg;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SetEditor(
            exercise: _exercise,
            unit: 'lbs',
            onAddPercentageSets: (_) {},
            onAddAbsoluteSets: (sets, reps, weightKg) {
              capturedSets = sets;
              capturedReps = reps;
              capturedWeightKg = weightKg;
            },
            onDeleteSet: (_) {},
          ),
        ),
      ),
    );

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
      MaterialApp(
        home: Scaffold(
          body: SetEditor(
            exercise: _exercise,
            unit: 'kg',
            onAddPercentageSets: (_) {},
            onAddAbsoluteSets: (_, _, weightKg) => capturedWeightKg = weightKg,
            onDeleteSet: (_) {},
          ),
        ),
      ),
    );

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
      MaterialApp(
        home: Scaffold(
          body: SetEditor(
            exercise: _exercise,
            unit: 'kg',
            onAddPercentageSets: (_) {},
            onAddAbsoluteSets: (_, _, _) {},
            onDeleteSet: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add sets (weight)'));
    await tester.pumpAndSettle();

    final row = find.ancestor(of: find.text('Sets'), matching: find.byType(Row));
    final decrement = find.ancestor(
      of: find.descendant(of: row, matching: find.byIcon(Icons.remove_circle_outline)),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(decrement).onPressed, isNull);
  });
}
