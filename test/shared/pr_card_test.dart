import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/shared/widgets/pr_card.dart';

void main() {
  testWidgets('hides the chevron when onTap is not provided', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PrCard(
            exerciseName: 'Back Squat',
            weightDisplay: '100.0 kg',
            reps: 5,
            dateDisplay: 'Jan 1, 2026',
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });

  testWidgets('shows the chevron and calls onTap when tapped', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrCard(
            exerciseName: 'Back Squat',
            weightDisplay: '100.0 kg',
            reps: 5,
            dateDisplay: 'Jan 1, 2026',
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.chevron_right), findsOneWidget);

    await tester.tap(find.byType(PrCard));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });
}
