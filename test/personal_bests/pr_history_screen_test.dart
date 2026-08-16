import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/personal_bests/models/personal_best.dart';
import 'package:nomorex/features/personal_bests/providers/personal_bests_provider.dart';
import 'package:nomorex/features/personal_bests/screens/pr_history_screen.dart';

class _StubPersonalBestsNotifier extends PersonalBestsNotifier {
  _StubPersonalBestsNotifier(this._prs);
  final List<PersonalBest> _prs;

  @override
  Future<List<PersonalBest>> build() async => _prs;
}

void main() {
  testWidgets('renders every history entry for the given exercise', (tester) async {
    final prs = [
      PersonalBest(
        id: '1',
        userId: 'u1',
        exerciseId: 'e1',
        exerciseName: 'Back Squat',
        weightKg: 100,
        reps: 5,
        date: DateTime(2026, 1, 1),
        notes: 'Felt strong, belt only, no wraps.\n'
            'Back tightened up on the walkout so next time set up shallower.',
        updatedAt: DateTime(2026, 1, 1),
      ),
      PersonalBest(
        id: '2',
        userId: 'u1',
        exerciseId: 'e1',
        exerciseName: 'Back Squat',
        weightKg: 90,
        reps: 5,
        date: DateTime(2025, 12, 1),
        updatedAt: DateTime(2025, 12, 1),
      ),
      // Different exercise — should not show up in history for e1.
      PersonalBest(
        id: '3',
        userId: 'u1',
        exerciseId: 'e2',
        exerciseName: 'Bench Press',
        weightKg: 80,
        reps: 5,
        date: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalBestsProvider.overrideWith(() => _StubPersonalBestsNotifier(prs)),
        ],
        child: const MaterialApp(home: PrHistoryScreen(exerciseId: 'e1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PR HISTORY'), findsOneWidget);
    expect(find.text('Back Squat'), findsWidgets);
    expect(find.text('Bench Press'), findsNothing);
  });

  testWidgets('shows the full note on a history entry', (tester) async {
    const note = 'Felt strong, belt only, no wraps.\n'
        'Back tightened up on the walkout so next time set up shallower.';
    final prs = [
      PersonalBest(
        id: '1',
        userId: 'u1',
        exerciseId: 'e1',
        exerciseName: 'Back Squat',
        weightKg: 100,
        reps: 5,
        date: DateTime(2026, 1, 1),
        notes: note,
        updatedAt: DateTime(2026, 1, 1),
      ),
      // No note — must not render an empty line.
      PersonalBest(
        id: '2',
        userId: 'u1',
        exerciseId: 'e1',
        exerciseName: 'Back Squat',
        weightKg: 90,
        reps: 5,
        date: DateTime(2025, 12, 1),
        updatedAt: DateTime(2025, 12, 1),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalBestsProvider.overrideWith(() => _StubPersonalBestsNotifier(prs)),
        ],
        child: const MaterialApp(home: PrHistoryScreen(exerciseId: 'e1')),
      ),
    );
    await tester.pumpAndSettle();

    final noteFinder = find.text(note);
    expect(noteFinder, findsOneWidget);
    // Unclipped on the detail screen.
    expect(tester.widget<Text>(noteFinder).maxLines, isNull);
  });

  testWidgets('shows an empty state when the exercise has no history', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalBestsProvider.overrideWith(() => _StubPersonalBestsNotifier(const [])),
        ],
        child: const MaterialApp(home: PrHistoryScreen(exerciseId: 'e1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No PR history found.'), findsOneWidget);
  });
}
