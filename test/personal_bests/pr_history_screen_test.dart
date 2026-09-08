import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nomorex/features/personal_bests/models/personal_best.dart';
import 'package:nomorex/features/personal_bests/providers/personal_bests_provider.dart';
import 'package:nomorex/features/personal_bests/screens/pr_history_screen.dart';

class _StubPersonalBestsNotifier extends PersonalBestsNotifier {
  _StubPersonalBestsNotifier(this._prs);
  final List<PersonalBest> _prs;

  @override
  Future<List<PersonalBest>> build() async => _prs;
}

class _RecordingPersonalBestsNotifier extends PersonalBestsNotifier {
  _RecordingPersonalBestsNotifier(this._prs, {this.onDelete});
  final List<PersonalBest> _prs;
  final void Function(String id)? onDelete;

  @override
  Future<List<PersonalBest>> build() async => _prs;

  @override
  Future<void> deletePr(String id) async {
    onDelete?.call(id);
  }
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

  testWidgets('tapping the add button opens the add-PR form pre-filled from the most recent PR',
      (tester) async {
    final prs = [
      PersonalBest(
        id: '1',
        userId: 'u1',
        exerciseId: 'e1',
        exerciseName: 'Clean Pull',
        weightKg: 152,
        reps: 5,
        date: DateTime(2026, 8, 31),
        updatedAt: DateTime(2026, 8, 31),
      ),
      // Older — must not be the one the add button pre-fills from.
      PersonalBest(
        id: '2',
        userId: 'u1',
        exerciseId: 'e1',
        exerciseName: 'Clean Pull',
        weightKg: 140,
        reps: 3,
        date: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    ];

    final router = GoRouter(
      initialLocation: '/prs/e1/history',
      routes: [
        GoRoute(
          path: '/prs/e1/history',
          builder: (_, _) => const PrHistoryScreen(exerciseId: 'e1'),
        ),
        GoRoute(
          path: '/prs/add',
          builder: (_, state) => Text('add:${state.uri.query}'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalBestsProvider.overrideWith(() => _StubPersonalBestsNotifier(prs)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pr_history_add')));
    await tester.pumpAndSettle();

    expect(find.text('add:exerciseId=e1&weightKg=152.0&reps=5'), findsOneWidget);
  });

  testWidgets('tapping the add button with no history opens a blank add-PR form',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/prs/e1/history',
      routes: [
        GoRoute(
          path: '/prs/e1/history',
          builder: (_, _) => const PrHistoryScreen(exerciseId: 'e1'),
        ),
        GoRoute(
          path: '/prs/add',
          builder: (_, state) => Text('add:${state.uri.query}'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalBestsProvider.overrideWith(() => _StubPersonalBestsNotifier(const [])),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pr_history_add')));
    await tester.pumpAndSettle();

    expect(find.text('add:exerciseId=e1'), findsOneWidget);
  });

  testWidgets('tapping a row\'s delete icon opens a confirmation dialog', (tester) async {
    final prs = [
      PersonalBest(
        id: '1',
        userId: 'u1',
        exerciseId: 'e1',
        exerciseName: 'Back Squat',
        weightKg: 100,
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

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Delete personal best?'), findsOneWidget);
  });

  testWidgets('canceling delete leaves deletePr uncalled', (tester) async {
    String? deletedId;
    final prs = [
      PersonalBest(
        id: '1',
        userId: 'u1',
        exerciseId: 'e1',
        exerciseName: 'Back Squat',
        weightKg: 100,
        reps: 5,
        date: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalBestsProvider.overrideWith(
            () => _RecordingPersonalBestsNotifier(prs, onDelete: (id) => deletedId = id),
          ),
        ],
        child: const MaterialApp(home: PrHistoryScreen(exerciseId: 'e1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Cancel'),
    ));
    await tester.pumpAndSettle();

    expect(deletedId, isNull);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('confirming delete calls deletePr with that entry\'s id', (tester) async {
    String? deletedId;
    final prs = [
      PersonalBest(
        id: '1',
        userId: 'u1',
        exerciseId: 'e1',
        exerciseName: 'Back Squat',
        weightKg: 100,
        reps: 5,
        date: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalBestsProvider.overrideWith(
            () => _RecordingPersonalBestsNotifier(prs, onDelete: (id) => deletedId = id),
          ),
        ],
        child: const MaterialApp(home: PrHistoryScreen(exerciseId: 'e1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Delete'),
    ));
    await tester.pumpAndSettle();

    expect(deletedId, '1');
  });
}
