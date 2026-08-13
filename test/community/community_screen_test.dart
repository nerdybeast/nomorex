import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/community/providers/community_workouts_provider.dart';
import 'package:nomorex/features/community/screens/community_screen.dart';
import 'package:nomorex/features/workouts/models/workout.dart';

class _StubCommunityWorkoutsNotifier extends CommunityWorkoutsNotifier {
  _StubCommunityWorkoutsNotifier(this._workouts);
  final List<Workout> _workouts;
  @override
  Future<List<Workout>> build() async => _workouts;
}

class _RecordingCommunityWorkoutsNotifier extends CommunityWorkoutsNotifier {
  _RecordingCommunityWorkoutsNotifier(this.onRefresh);
  final VoidCallback onRefresh;
  @override
  Future<List<Workout>> build() async => const [];
  @override
  Future<void> refresh() async => onRefresh();
}

void main() {
  testWidgets('lists public workouts without any owner attribution', (tester) async {
    final workouts = [
      Workout(
        id: 'w1',
        userId: 'other-user',
        title: '5x5 Strength',
        date: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
        isPublic: true,
      ),
      Workout(
        id: 'w2',
        userId: 'other-user',
        title: 'Push Pull Legs',
        date: DateTime(2026, 7, 2),
        updatedAt: DateTime(2026, 7, 2),
        isPublic: true,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          communityWorkoutsProvider.overrideWith(
            () => _StubCommunityWorkoutsNotifier(workouts),
          ),
        ],
        child: const MaterialApp(home: CommunityScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('5x5 Strength'), findsOneWidget);
    expect(find.text('Push Pull Legs'), findsOneWidget);
    expect(find.textContaining('by '), findsNothing);
  });

  testWidgets('search field filters the community list by title', (tester) async {
    final workouts = [
      Workout(
        id: 'w1',
        userId: 'other-user',
        title: '5x5 Strength',
        date: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
        isPublic: true,
      ),
      Workout(
        id: 'w2',
        userId: 'other-user',
        title: 'Push Pull Legs',
        date: DateTime(2026, 7, 2),
        updatedAt: DateTime(2026, 7, 2),
        isPublic: true,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          communityWorkoutsProvider.overrideWith(
            () => _StubCommunityWorkoutsNotifier(workouts),
          ),
        ],
        child: const MaterialApp(home: CommunityScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '5x5');
    await tester.pumpAndSettle();

    expect(find.text('5x5 Strength'), findsOneWidget);
    expect(find.text('Push Pull Legs'), findsNothing);
  });

  testWidgets('tapping the refresh icon calls refresh on the notifier', (tester) async {
    var refreshed = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          communityWorkoutsProvider.overrideWith(
            () => _RecordingCommunityWorkoutsNotifier(() => refreshed = true),
          ),
        ],
        child: const MaterialApp(home: CommunityScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    expect(refreshed, isTrue);
  });
}
