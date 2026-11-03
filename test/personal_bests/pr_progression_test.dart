import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/core/utils/one_rep_max_formula.dart';
import 'package:nomorex/features/personal_bests/models/personal_best.dart';
import 'package:nomorex/features/personal_bests/widgets/pr_progression.dart';

PersonalBest _pr(double weightKg, int reps, DateTime date) => PersonalBest(
      id: '$weightKg-$reps-$date',
      userId: 'u1',
      exerciseId: 'e1',
      exerciseName: 'Tall Clean',
      weightKg: weightKg,
      reps: reps,
      date: date,
      updatedAt: date,
    );

Future<void> _pump(WidgetTester tester, List<PersonalBest> entries) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: PrProgression(
              entries: entries,
              formula: OneRepMaxFormula.brzycki,
            ),
          ),
        ),
      ),
    );

const _chart = Key('pr_progression_chart');
const _hint = Key('pr_progression_hint');

String _hintText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(_hint)).data!;

void main() {
  testWidgets('draws the trend once there are three entries', (tester) async {
    await _pump(tester, [
      _pr(50, 1, DateTime(2022, 10, 19)),
      _pr(55, 1, DateTime(2023, 5, 16)),
      _pr(75, 1, DateTime(2024, 12, 5)),
      _pr(60, 1, DateTime(2026, 11, 2)),
    ]);

    expect(find.byKey(_chart), findsOneWidget);
    expect(find.byKey(_hint), findsNothing);
  });

  testWidgets('counts progress toward the trend with two entries',
      (tester) async {
    await _pump(tester, [
      _pr(50, 1, DateTime(2026, 1, 1)),
      _pr(55, 1, DateTime(2026, 2, 1)),
    ]);

    expect(find.byKey(_chart), findsNothing);
    expect(
      _hintText(tester),
      'Progression trend line will show after the PR has multiple updates. '
      '2 / 3 updates completed!',
    );
  });

  testWidgets('shows 1 / 3 for a single entry', (tester) async {
    await _pump(tester, [_pr(50, 1, DateTime(2026, 1, 1))]);

    expect(_hintText(tester), contains('1 / 3 updates completed!'));
  });

  testWidgets('entries that cannot be estimated do not count', (tester) async {
    await _pump(tester, [
      _pr(50, 1, DateTime(2026, 1, 1)),
      _pr(55, 1, DateTime(2026, 2, 1)),
      _pr(40, 15, DateTime(2026, 3, 1)),
    ]);

    expect(find.byKey(_chart), findsNothing);
    expect(_hintText(tester), contains('2 / 3 updates completed!'));
  });

  testWidgets('paints without error when every entry is the same weight and day',
      (tester) async {
    final day = DateTime(2026, 1, 1);
    await _pump(tester, [_pr(50, 1, day), _pr(50, 1, day), _pr(50, 1, day)]);

    expect(find.byKey(_chart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
