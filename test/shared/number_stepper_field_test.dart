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

    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pump();

    // 205 + 2.5 -> 207.5, a genuine fraction, so the decimal now shows.
    expect(find.text('207.5'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pump();

    // 207.5 + 2.5 -> 210, back to a whole number.
    expect(find.text('210'), findsOneWidget);
  });
}
