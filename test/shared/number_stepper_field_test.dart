import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/shared/widgets/number_stepper_field.dart';

Widget _wrap(NumberStepperField field) => MaterialApp(home: Scaffold(body: field));

void main() {
  testWidgets('a whole-number value displays without a trailing decimal', (tester) async {
    await tester.pumpWidget(_wrap(NumberStepperField(
      label: 'Weight',
      value: 205,
      min: 0,
      step: 2.5,
      decimals: 1,
      onChanged: (_) {},
    )));

    expect(find.text('205'), findsOneWidget);
    expect(find.text('205.0'), findsNothing);
  });

  testWidgets('zero displays as "0", not "0.0"', (tester) async {
    await tester.pumpWidget(_wrap(NumberStepperField(
      label: 'Weight',
      value: 0,
      min: 0,
      step: 2.5,
      decimals: 1,
      onChanged: (_) {},
    )));

    expect(find.text('0'), findsOneWidget);
    expect(find.text('0.0'), findsNothing);
  });

  testWidgets('a fractional value keeps its decimal', (tester) async {
    await tester.pumpWidget(_wrap(NumberStepperField(
      label: 'Weight',
      value: 205.5,
      min: 0,
      step: 2.5,
      decimals: 1,
      onChanged: (_) {},
    )));

    expect(find.text('205.5'), findsOneWidget);
  });

  testWidgets('decimals: 0 never shows a decimal point', (tester) async {
    await tester.pumpWidget(_wrap(NumberStepperField(
      label: 'Reps',
      value: 5,
      min: 1,
      step: 1,
      decimals: 0,
      onChanged: (_) {},
    )));

    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('incrementing past a whole number keeps the trimmed format', (tester) async {
    var value = 205.0;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => _wrap(NumberStepperField(
          label: 'Weight',
          value: value,
          min: 0,
          step: 2.5,
          decimals: 1,
          onChanged: (v) => setState(() => value = v),
        )),
      ),
    );

    expect(find.text('205'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // 205 + 2.5 -> 207.5, a genuine fraction, so the decimal now shows.
    expect(find.text('207.5'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // 207.5 + 2.5 -> 210, back to a whole number.
    expect(find.text('210'), findsOneWidget);
  });

  testWidgets('the -/+ buttons are named after the field for assistive tech', (tester) async {
    final handle = tester.ensureSemantics();
    double? changed;
    await tester.pumpWidget(_wrap(NumberStepperField(
      label: 'Reps',
      value: 5,
      min: 1,
      step: 1,
      decimals: 0,
      onChanged: (v) => changed = v,
    )));

    expect(find.bySemanticsLabel('Decrease Reps'), findsOneWidget);
    expect(find.bySemanticsLabel('Increase Reps'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Increase Reps'));
    expect(changed, 6);
    handle.dispose();
  });

  group('typed entry', () {
    Future<List<double>> pumpStateful(WidgetTester tester, {double start = 0, double min = 0, double? max}) async {
      final changes = <double>[];
      var value = start;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => _wrap(NumberStepperField(
            label: 'Weight',
            value: value,
            min: min,
            max: max,
            step: 2.5,
            decimals: 1,
            onChanged: (v) {
              changes.add(v);
              setState(() => value = v);
            },
          )),
        ),
      );
      return changes;
    }

    testWidgets('is reported without submitting or leaving the field', (tester) async {
      // iOS's number pad has no Done key, and tapping a dialog's Save button
      // doesn't unfocus the field, so the value must arrive as it's typed.
      final changes = await pumpStateful(tester);

      await tester.enterText(find.byType(TextField), '100');
      await tester.pump();

      expect(changes.last, 100);
      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('is not reformatted mid-edit', (tester) async {
      await pumpStateful(tester);

      await tester.enterText(find.byType(TextField), '10.');
      await tester.pump();

      expect(find.text('10.'), findsOneWidget);
    });

    testWidgets('is clamped, and the text tidied on submit', (tester) async {
      final changes = await pumpStateful(tester, start: 5, min: 0, max: 50);

      await tester.enterText(find.byType(TextField), '80');
      await tester.pump();
      expect(changes.last, 50);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.text('50'), findsOneWidget);
    });

    testWidgets('the +/- buttons step from the typed value', (tester) async {
      await pumpStateful(tester);

      await tester.enterText(find.byType(TextField), '100');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(find.text('102.5'), findsOneWidget);
    });

    testWidgets('unparseable text reports nothing', (tester) async {
      final changes = await pumpStateful(tester, start: 5);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();

      expect(changes, isEmpty);
    });
  });
}
