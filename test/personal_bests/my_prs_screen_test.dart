import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/personal_bests/models/personal_best.dart';
import 'package:nomorex/features/personal_bests/providers/personal_bests_provider.dart';
import 'package:nomorex/features/personal_bests/screens/my_prs_screen.dart';
import 'package:nomorex/shared/widgets/dashboard_empty_state_card.dart';

final _prs = [
  PersonalBest(
    id: '1',
    userId: 'u1',
    exerciseId: 'e1',
    exerciseName: 'Back Squat',
    weightKg: 100,
    reps: 5,
    date: DateTime(2026, 1, 1),
    notes: 'Felt strong, belt only.',
    updatedAt: DateTime(2026, 1, 1),
  ),
];

class _RecordingPersonalBestsNotifier extends PersonalBestsNotifier {
  _RecordingPersonalBestsNotifier(this.onRefresh);
  final VoidCallback onRefresh;
  int refreshCount = 0;

  @override
  Future<List<PersonalBest>> build() async => _prs;

  @override
  Future<void> refresh() async {
    refreshCount++;
    onRefresh();
  }
}

class _StubPersonalBestsNotifier extends PersonalBestsNotifier {
  _StubPersonalBestsNotifier(this._items);
  final List<PersonalBest> _items;
  @override
  Future<List<PersonalBest>> build() async => _items;
}

void main() {
  testWidgets('no PRs shows an empty-state card with a log-first-PR action', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalBestsProvider.overrideWith(() => _StubPersonalBestsNotifier(const [])),
        ],
        child: const MaterialApp(home: MyPrsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DashboardEmptyStateCard), findsOneWidget);
    expect(find.text('No PRs yet.'), findsOneWidget);
    expect(find.text('Log your first PR'), findsOneWidget);
  });

  testWidgets('a search with no matches keeps the plain "No PRs found." text', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalBestsProvider.overrideWith(() => _StubPersonalBestsNotifier(_prs)),
        ],
        child: const MaterialApp(home: MyPrsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();

    expect(find.text('No PRs found.'), findsOneWidget);
    expect(find.byType(DashboardEmptyStateCard), findsNothing);
  });

  testWidgets('tapping the refresh icon calls refresh on the notifier', (tester) async {
    var refreshed = false;
    final notifier = _RecordingPersonalBestsNotifier(() => refreshed = true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalBestsProvider.overrideWith(() => notifier),
        ],
        child: const MaterialApp(home: MyPrsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    expect(refreshed, isTrue);
    expect(notifier.refreshCount, 1);
  });

  testWidgets('renders PRs and the search field', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalBestsProvider.overrideWith(
            () => _RecordingPersonalBestsNotifier(() {}),
          ),
        ],
        child: const MaterialApp(home: MyPrsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MY PRS'), findsOneWidget);
    expect(find.text('Back Squat'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });

  testWidgets('shows the PR note, clipped to two lines', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalBestsProvider.overrideWith(
            () => _RecordingPersonalBestsNotifier(() {}),
          ),
        ],
        child: const MaterialApp(home: MyPrsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final noteFinder = find.text('Felt strong, belt only.');
    expect(noteFinder, findsOneWidget);
    expect(tester.widget<Text>(noteFinder).maxLines, 2);
  });
}
