import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/exercises/widgets/exercise_picker.dart';

import '../harness.dart';

/// The "NEW PERSONAL BEST" screen at `/prs/add`.
class AddPrPage {
  AddPrPage(this.tester);

  final WidgetTester tester;

  static final weightStepper = find.byKey(const Key('add_pr_weight'));
  static final repsStepper = find.byKey(const Key('add_pr_reps'));
  static final submitButton = find.byKey(const Key('add_pr_submit'));

  /// The picker deliberately has no test key — its existing
  /// `ValueKey(_prefilledFromArg)` is load-bearing (it forces a remount once
  /// the exercise list resolves), so reach the field through the type instead.
  static final _exerciseField = find.descendant(
    of: find.byType(ExercisePicker),
    matching: find.byType(TextFormField),
  );

  Future<void> waitUntilLoaded() => waitFor(tester, submitButton);

  /// Types [name] into the autocomplete and taps the matching overlay tile.
  Future<void> selectExercise(String name) async {
    await tester.tap(_exerciseField);
    await tester.pumpAndSettle();
    await tester.enterText(_exerciseField, name);
    await tester.pumpAndSettle();

    // The overlay always appends an "Add custom exercise" tile, so filter to
    // the tile actually carrying the exercise name.
    final option = find.widgetWithText(ListTile, name);
    await waitFor(tester, option);
    await tester.tap(option.first);
    await tester.pumpAndSettle();
  }

  Future<void> setWeight(double value) => _setStepper(weightStepper, value);

  Future<void> setReps(int value) => _setStepper(repsStepper, value.toDouble());

  /// Types straight into the stepper's middle field rather than tapping [+]
  /// dozens of times. `NumberStepperField` only commits a typed value on blur
  /// or on submit, so fire the submit action explicitly.
  Future<void> _setStepper(Finder stepper, double value) async {
    final field = find.descendant(
      of: stepper,
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();

    await tester.enterText(field, value.toString());
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  /// Saves and waits for the screen to pop back to whatever pushed it.
  Future<void> save() async {
    await tester.ensureVisible(submitButton);
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(submitButton);
    expect(
      button.onPressed,
      isNotNull,
      reason: 'Save is disabled until an exercise is selected',
    );

    await tester.tap(submitButton);
    await waitForAbsent(tester, submitButton);
    await tester.pumpAndSettle();
  }
}
