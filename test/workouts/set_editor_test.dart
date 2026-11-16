import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/core/utils/weight_converter.dart';
import 'package:nomorex/features/exercises/models/exercise.dart';
import 'package:nomorex/features/exercises/providers/exercises_provider.dart';
import 'package:nomorex/features/workouts/utils/parsed_set.dart';
import 'package:nomorex/features/workouts/widgets/set_editor.dart';
import 'package:nomorex/features/workouts/providers/one_rep_max_provider.dart';
import 'package:nomorex/shared/models/editable_set_row.dart';
import 'package:nomorex/shared/models/one_rep_max.dart';

const _otherExercise = Exercise(
  id: 'e2',
  name: 'Front Squat',
  isPredefined: true,
);

class _StubExercisesNotifier extends ExercisesNotifier {
  @override
  Future<List<Exercise>> build() async => const [_otherExercise];
}

Future<void> _pump(WidgetTester tester, Widget child, {Map<String, OneRepMax> oneRepMaxes = const {}}) =>
    tester.pumpWidget(ProviderScope(
      overrides: [
        exercisesProvider.overrideWith(() => _StubExercisesNotifier()),
        oneRepMaxProvider.overrideWith((ref) async => oneRepMaxes),
        oneRepMaxByNameProvider.overrideWith((ref) async => const {}),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    ));

/// The editor under test, keyed to exercise 'e1' / 'Back Squat'.
SetEditor _editor() => SetEditor(
  sets: const [],
  unit: 'kg',
  currentExerciseId: 'e1',
  currentExerciseName: 'Back Squat',
  onAddPercentageSets: (_) async {},
  onAddAbsoluteSets: (_) async {},
  onReplaceGroup: (_, _, _) async {},
  onReorderSets: (_) async {},
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
  testWidgets('Add sets (%) applies one percentage to every set in the batch', (
    tester,
  ) async {
    List<ParsedSet>? added;

    await _pump(
      tester,
      SetEditor(
        sets: const [],
        unit: 'kg',
        currentExerciseId: 'e1',
        currentExerciseName: 'Front Squat',
        onAddPercentageSets: (parsed) async => added = parsed,
        onAddAbsoluteSets: (_) async {},
        onReplaceGroup: (_, _, _) async {},
        onReorderSets: (_) async {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add sets (%)'));
    await tester.pumpAndSettle();

    // Growing from 1 to 3 sets must not add a stepper per set — the dialog
    // stays a fixed height.
    await _tapStepper(
      tester,
      label: 'Sets',
      icon: Icons.add,
      times: 2,
    );
    expect(find.text('%1RM'), findsOneWidget);
    expect(find.text('Set 1 %1RM'), findsNothing);
    expect(find.text('Set 2 %1RM'), findsNothing);

    // Nudge the shared percentage up from the 70 default.
    await _tapStepper(
      tester,
      label: '%1RM',
      icon: Icons.add,
    );

    await tester.tap(find.byKey(const Key('set_editor_add')));
    await tester.pumpAndSettle();

    expect(added, isNotNull);
    expect(added!.map((s) => s.targetReps), [1, 1, 1]);
    expect(added!.map((s) => s.percentage), [75, 75, 75]);
    expect(added!.map((s) => s.basisExerciseId), [null, null, null]);
  });

  testWidgets(
    '"Based on" defaults to this exercise and flows through when changed',
    (tester) async {
      List<ParsedSet>? added;

      await _pump(
        tester,
        SetEditor(
          sets: const [],
          unit: 'kg',
          currentExerciseId: 'e1',
          currentExerciseName: 'Front Squat',
          onAddPercentageSets: (parsed) async => added = parsed,
          onAddAbsoluteSets: (_) async {},
          onReplaceGroup: (_, _, _) async {},
          onReorderSets: (_) async {},
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add sets (%)'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('set_editor_basis')), findsOneWidget);

      await tester.tap(find.byKey(const Key('set_editor_basis')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Front Squat').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('set_editor_add')));
      await tester.pumpAndSettle();

      expect(added, isNotNull);
      expect(added!.single.basisExerciseId, 'e2');
    },
  );

  testWidgets(
    'Add sets (weight) collects sets/reps/weight and converts lbs to kg',
    (tester) async {
      int? capturedSets;
      int? capturedReps;
      double? capturedWeightKg;

      await _pump(
        tester,
        SetEditor(
          sets: const [],
          unit: 'lbs',
          currentExerciseId: 'e1',
          currentExerciseName: 'Front Squat',
          onAddPercentageSets: (_) async {},
          onAddAbsoluteSets: (batch) async {
            capturedSets = batch.sets;
            capturedReps = batch.reps;
            capturedWeightKg = batch.weightKg;
          },
          onReplaceGroup: (_, _, _) async {},
          onReorderSets: (_) async {},
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add sets (weight)'));
      await tester.pumpAndSettle();

      await _tapStepper(tester, label: 'Sets', icon: Icons.add);
      await _tapStepper(
        tester,
        label: 'Reps',
        icon: Icons.add,
        times: 4,
      );
      await _tapStepper(
        tester,
        label: 'Weight (lbs)',
        icon: Icons.add,
      );

      await tester.tap(find.byKey(const Key('set_editor_add')));
      await tester.pumpAndSettle();

      expect(capturedSets, 2);
      expect(capturedReps, 5);
      expect(capturedWeightKg, closeTo(lbsToKg(5), 0.001));
    },
  );

  testWidgets(
    'Add sets (weight) shows a static unit chip, not a toggle, when the '
    'profile preference is fixed to lbs',
    (tester) async {
      await _pump(
        tester,
        SetEditor(
          sets: const [],
          unit: 'lbs',
          currentExerciseId: 'e1',
          currentExerciseName: 'Front Squat',
          onAddPercentageSets: (_) async {},
          onAddAbsoluteSets: (_) async {},
          onReplaceGroup: (_, _, _) async {},
          onReorderSets: (_) async {},
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add sets (weight)'));
      await tester.pumpAndSettle();

      expect(find.text('Weight (lbs)'), findsOneWidget);
      // No 'kg' segment to switch to — nothing to choose when the preference
      // is fixed to a single unit.
      expect(find.text('kg'), findsNothing);
    },
  );

  testWidgets(
    'Add sets (weight) unit toggle lets weight be entered in either unit '
    "when the profile preference is 'both'",
    (tester) async {
      double? capturedWeightKg;

      await _pump(
        tester,
        SetEditor(
          sets: const [],
          unit: 'both',
          currentExerciseId: 'e1',
          currentExerciseName: 'Front Squat',
          onAddPercentageSets: (_) async {},
          onAddAbsoluteSets: (batch) async => capturedWeightKg = batch.weightKg,
          onReplaceGroup: (_, _, _) async {},
          onReorderSets: (_) async {},
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add sets (weight)'));
      await tester.pumpAndSettle();

      // Defaults to kg when the preference is 'both'.
      expect(find.text('Weight (kg)'), findsOneWidget);

      await tester.tap(find.text('lbs'));
      await tester.pumpAndSettle();

      expect(find.text('Weight (lbs)'), findsOneWidget);

      await tester.tap(find.text('kg'));
      await tester.pumpAndSettle();

      expect(find.text('Weight (kg)'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, '0'), '100');
      final repsRow = find.ancestor(
        of: find.text('Reps'),
        matching: find.byType(Row),
      );
      await tester.tap(
        find.descendant(of: repsRow, matching: find.byType(TextField)),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('set_editor_add')));
      await tester.pumpAndSettle();

      expect(capturedWeightKg, 100);
    },
  );

  testWidgets('typing a weight directly and moving focus away commits it, even '
      'without pressing enter', (tester) async {
    double? capturedWeightKg;

    await _pump(
      tester,
      SetEditor(
        sets: const [],
        unit: 'kg',
        currentExerciseId: 'e1',
        currentExerciseName: 'Front Squat',
        onAddPercentageSets: (_) async {},
        onAddAbsoluteSets: (batch) async => capturedWeightKg = batch.weightKg,
        onReplaceGroup: (_, _, _) async {},
        onReorderSets: (_) async {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add sets (weight)'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '0'), '102.5');
    // Move focus to another field (e.g. tabbing away) without submitting via
    // enter — a Text tap wouldn't actually shift focus, so target the Reps
    // TextField instead.
    final repsRow = find.ancestor(
      of: find.text('Reps'),
      matching: find.byType(Row),
    );
    await tester.tap(
      find.descendant(of: repsRow, matching: find.byType(TextField)),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('set_editor_add')));
    await tester.pumpAndSettle();

    expect(capturedWeightKg, 102.5);
  });

  testWidgets('sets stepper cannot go below 1', (tester) async {
    await _pump(
      tester,
      SetEditor(
        sets: const [],
        unit: 'kg',
        currentExerciseId: 'e1',
        currentExerciseName: 'Front Squat',
        onAddPercentageSets: (_) async {},
        onAddAbsoluteSets: (_) async {},
        onReplaceGroup: (_, _, _) async {},
        onReorderSets: (_) async {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add sets (weight)'));
    await tester.pumpAndSettle();

    final row = find.ancestor(
      of: find.text('Sets'),
      matching: find.byType(Row),
    );
    final decrement = find.ancestor(
      of: find.descendant(
        of: row,
        matching: find.byIcon(Icons.remove),
      ),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(decrement).onPressed, isNull);
  });

  testWidgets('renders "% of <basis>" when a set has a basis exercise', (
    tester,
  ) async {
    await _pump(
      tester,
      SetEditor(
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
        currentExerciseId: 'e1',
        currentExerciseName: 'Front Squat',
        onAddPercentageSets: (_) async {},
        onAddAbsoluteSets: (_) async {},
        onReplaceGroup: (_, _, _) async {},
        onReorderSets: (_) async {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('85% of Front Squat'), findsOneWidget);
  });

  group('Add sets (%) shows the 1RM the percentages resolve against', () {
    testWidgets('a measured single renders plainly', (tester) async {
      await _pump(tester, _editor(), oneRepMaxes: const {'e1': OneRepMax.measured(165)});
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add sets (%)'));
      await tester.pumpAndSettle();

      expect(find.text('1RM 165 kg'), findsOneWidget);
    });

    testWidgets('an inferred max is labelled as an estimate', (tester) async {
      await _pump(tester, _editor(), oneRepMaxes: const {'e1': OneRepMax.estimated(112.5)});
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add sets (%)'));
      await tester.pumpAndSettle();

      expect(find.text('Est. 1RM 112.5 kg'), findsOneWidget);
    });

    testWidgets('says so when the lift has no 1RM at all', (tester) async {
      await _pump(tester, _editor());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add sets (%)'));
      await tester.pumpAndSettle();

      expect(find.text('No 1RM recorded for this lift'), findsOneWidget);
    });

    testWidgets('offers a set-PR link beside the basis when there is no 1RM', (tester) async {
      await _pump(tester, _editor());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add sets (%)'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('set_editor_basis_set_pr')), findsOneWidget);
    });

    testWidgets('no set-PR link once the basis lift has a 1RM', (tester) async {
      await _pump(tester, _editor(), oneRepMaxes: const {'e1': OneRepMax.measured(165)});
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add sets (%)'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('set_editor_basis_set_pr')), findsNothing);
    });

    testWidgets('follows the basis exercise chosen in the dropdown', (
      tester,
    ) async {
      await _pump(
        tester,
        _editor(),
        oneRepMaxes: const {
          'e1': OneRepMax.measured(165),
          'e2': OneRepMax.measured(90),
        },
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add sets (%)'));
      await tester.pumpAndSettle();
      expect(find.text('1RM 165 kg'), findsOneWidget);

      // "Based on" -> Front Squat (e2), a different lift's 1RM.
      await tester.tap(find.byKey(const Key('set_editor_basis')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Front Squat').last);
      await tester.pumpAndSettle();

      expect(find.text('1RM 90 kg'), findsOneWidget);
      expect(find.text('1RM 165 kg'), findsNothing);
    });
  });

  testWidgets('dragging a set\'s handle below the next set calls onReorderSets '
      'with the new id order', (tester) async {
    List<String>? reordered;

    await _pump(
      tester,
      SetEditor(
        sets: const [
          EditableSetRow(
            id: 's1',
            weightMode: 'absolute',
            targetReps: 14,
            absoluteWeightKg: 50,
          ),
          EditableSetRow(
            id: 's2',
            weightMode: 'absolute',
            targetReps: 15,
            absoluteWeightKg: 45,
          ),
          EditableSetRow(
            id: 's3',
            weightMode: 'absolute',
            targetReps: 16,
            absoluteWeightKg: 40,
          ),
        ],
        unit: 'kg',
        currentExerciseId: 'e1',
        currentExerciseName: 'Back Squat',
        onAddPercentageSets: (_) async {},
        onAddAbsoluteSets: (_) async {},
        onReplaceGroup: (_, _, _) async {},
        onReorderSets: (ids) async => reordered = ids,
      ),
    );
    await tester.pumpAndSettle();

    // Three different sets, so three groups, each with its own handle.
    final handles = find.byIcon(Icons.drag_indicator);
    expect(handles, findsNWidgets(3));

    // Rows are 48px: about one row down puts s1 after s2 but before s3.
    final drag = await tester.startGesture(tester.getCenter(handles.first));
    await tester.pump(kPressTimeout);
    for (var i = 0; i < 3; i++) {
      await drag.moveBy(const Offset(0, 20));
      await tester.pump();
    }
    await drag.up();
    await tester.pumpAndSettle();

    expect(reordered, isNotNull);
    expect(reordered, ['s2', 's1', 's3']);
  });

  testWidgets('a single set is removed from its menu without a confirm', (tester) async {
    final replaced = <(List<String>, int)>[];

    await _pump(
      tester,
      SetEditor(
        sets: const [
          EditableSetRow(id: 's1', weightMode: 'absolute', targetReps: 14, absoluteWeightKg: 50),
          EditableSetRow(id: 's2', weightMode: 'absolute', targetReps: 15, absoluteWeightKg: 45),
        ],
        unit: 'kg',
        currentExerciseId: 'e1',
        currentExerciseName: 'Back Squat',
        onAddPercentageSets: (_) async {},
        onAddAbsoluteSets: (_) async {},
        onReplaceGroup: (ids, count, _) async => replaced.add((ids, count)),
        onReorderSets: (_) async {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('set_group_more_s1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove set'));
    await tester.pumpAndSettle();

    expect(replaced.single.$1, ['s1']);
    expect(replaced.single.$2, 0);
  });

  testWidgets('removing a group of several sets asks first', (tester) async {
    final replaced = <(List<String>, int)>[];

    await _pump(
      tester,
      SetEditor(
        sets: const [
          EditableSetRow(id: 's1', weightMode: 'absolute', targetReps: 3, absoluteWeightKg: 50),
          EditableSetRow(id: 's2', weightMode: 'absolute', targetReps: 3, absoluteWeightKg: 50),
          EditableSetRow(id: 's3', weightMode: 'absolute', targetReps: 3, absoluteWeightKg: 50),
        ],
        unit: 'kg',
        currentExerciseId: 'e1',
        currentExerciseName: 'Back Squat',
        onAddPercentageSets: (_) async {},
        onAddAbsoluteSets: (_) async {},
        onReplaceGroup: (ids, count, _) async => replaced.add((ids, count)),
        onReorderSets: (_) async {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3 × 3'), findsOneWidget, reason: 'identical sets read as one group');
    await tester.tap(find.byKey(const ValueKey('set_group_more_s1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove 3 sets'));
    await tester.pumpAndSettle();
    expect(find.text('Remove 3 sets?'), findsOneWidget);
    expect(replaced, isEmpty, reason: 'nothing is removed before confirming');

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(replaced.single.$1, ['s1', 's2', 's3']);
    expect(replaced.single.$2, 0);
  });
}
