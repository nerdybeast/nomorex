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

  testWidgets('renders the note when one is provided', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PrCard(
            exerciseName: 'Back Squat',
            weightDisplay: '100.0 kg',
            reps: 5,
            dateDisplay: 'Jan 1, 2026',
            notes: 'Felt strong, belt only.',
          ),
        ),
      ),
    );

    final noteFinder = find.text('Felt strong, belt only.');
    expect(noteFinder, findsOneWidget);
    // Unclipped by default.
    expect(tester.widget<Text>(noteFinder).maxLines, isNull);
    expect(tester.widget<Text>(noteFinder).overflow, isNull);
  });

  testWidgets('clips the note when notesMaxLines is set', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PrCard(
            exerciseName: 'Back Squat',
            weightDisplay: '100.0 kg',
            reps: 5,
            dateDisplay: 'Jan 1, 2026',
            notes: 'Felt strong, belt only.',
            notesMaxLines: 2,
          ),
        ),
      ),
    );

    final note = tester.widget<Text>(find.text('Felt strong, belt only.'));
    expect(note.maxLines, 2);
    expect(note.overflow, TextOverflow.ellipsis);
  });

  testWidgets('renders no note line when notes is null or empty', (tester) async {
    // A card with no note should show exactly the name, date, weight and reps.
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
    expect(find.byType(Text), findsNWidgets(4));

    // Rows saved before notes were trimmed on insert can hold '' — treat that
    // the same as null rather than rendering a blank line.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PrCard(
            exerciseName: 'Back Squat',
            weightDisplay: '100.0 kg',
            reps: 5,
            dateDisplay: 'Jan 1, 2026',
            notes: '',
          ),
        ),
      ),
    );
    expect(find.byType(Text), findsNWidgets(4));
  });
}
