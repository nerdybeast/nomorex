import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/shared/widgets/program_instance_card.dart';
import 'package:nomorex/shared/widgets/recent_workout_card.dart';
import 'package:nomorex/shared/widgets/workout_in_progress_card.dart';

/// The three dashboard cards follow the same chevron convention as [PrCard]:
/// a trailing chevron exactly when the card navigates somewhere.
void main() {
  Future<void> pump(WidgetTester tester, Widget card) => tester.pumpWidget(
        MaterialApp(home: Scaffold(body: card)),
      );

  group('ProgramInstanceCard', () {
    testWidgets('hides the chevron when onTap is not provided', (tester) async {
      await pump(
        tester,
        const ProgramInstanceCard(
          programName: 'Strong Like Bull',
          statusDisplay: 'In progress — started Aug 5, 2026',
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('shows the chevron and calls onTap when tapped', (tester) async {
      var tapped = false;

      await pump(
        tester,
        ProgramInstanceCard(
          programName: 'Strong Like Bull',
          statusDisplay: 'In progress — started Aug 5, 2026',
          onTap: () => tapped = true,
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      await tester.tap(find.byType(ProgramInstanceCard));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });

  group('WorkoutInProgressCard', () {
    testWidgets('hides the chevron when onTap is not provided', (tester) async {
      await pump(
        tester,
        const WorkoutInProgressCard(
          title: 'Push Day',
          statusDisplay: 'In progress — started 2:45 PM',
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('shows the chevron and calls onTap when tapped', (tester) async {
      var tapped = false;

      await pump(
        tester,
        WorkoutInProgressCard(
          title: 'Push Day',
          statusDisplay: 'In progress — started 2:45 PM',
          onTap: () => tapped = true,
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      await tester.tap(find.byType(WorkoutInProgressCard));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });

  group('RecentWorkoutCard', () {
    testWidgets('hides the chevron when onTap is not provided', (tester) async {
      await pump(
        tester,
        const RecentWorkoutCard(
          title: 'Push Day',
          completedDisplay: 'Completed Aug 11, 2026',
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('shows the chevron and calls onTap when tapped', (tester) async {
      var tapped = false;

      await pump(
        tester,
        RecentWorkoutCard(
          title: 'Push Day',
          completedDisplay: 'Completed Aug 11, 2026',
          onTap: () => tapped = true,
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      await tester.tap(find.byType(RecentWorkoutCard));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('a long title does not push the chevron off the card', (tester) async {
      await pump(
        tester,
        RecentWorkoutCard(
          title: 'A very long workout title that has to wrap across more than '
              'one line before it runs out of room',
          completedDisplay: 'Completed Aug 11, 2026',
          onTap: () {},
        ),
      );

      // An unbounded Row would overflow here rather than wrap the text.
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });
  });
}
