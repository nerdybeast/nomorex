import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/workouts/models/workout.dart';
import 'package:nomorex/features/workouts/providers/workouts_provider.dart';
import 'package:nomorex/features/workouts/screens/workouts_screen.dart';

class _StubWorkoutsNotifier extends WorkoutsNotifier {
  _StubWorkoutsNotifier(this._workouts);
  final List<Workout> _workouts;
  @override
  Future<List<Workout>> build() async => _workouts;
}

class _RecordingWorkoutsNotifier extends WorkoutsNotifier {
  _RecordingWorkoutsNotifier(this.onRefresh);
  final VoidCallback onRefresh;
  @override
  Future<List<Workout>> build() async => const [];
  @override
  Future<void> refresh() async => onRefresh();
}

void main() {
  testWidgets('search field filters the workouts list by title', (tester) async {
    final workouts = [
      Workout(
        id: 'w1',
        userId: 'u1',
        title: 'Push Day',
        date: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
      ),
      Workout(
        id: 'w2',
        userId: 'u1',
        title: 'Pull Day',
        date: DateTime(2026, 7, 2),
        updatedAt: DateTime(2026, 7, 2),
      ),
      Workout(
        id: 'w3',
        userId: 'u1',
        title: 'Leg Day',
        date: DateTime(2026, 7, 3),
        updatedAt: DateTime(2026, 7, 3),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutsProvider.overrideWith(() => _StubWorkoutsNotifier(workouts)),
        ],
        child: const MaterialApp(home: WorkoutsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Push Day'), findsOneWidget);
    expect(find.text('Pull Day'), findsOneWidget);
    expect(find.text('Leg Day'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Push');
    await tester.pumpAndSettle();

    expect(find.text('Push Day'), findsOneWidget);
    expect(find.text('Pull Day'), findsNothing);
    expect(find.text('Leg Day'), findsNothing);
  });

  testWidgets('search with no matches shows an empty-state message', (tester) async {
    final workouts = [
      Workout(
        id: 'w1',
        userId: 'u1',
        title: 'Push Day',
        date: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutsProvider.overrideWith(() => _StubWorkoutsNotifier(workouts)),
        ],
        child: const MaterialApp(home: WorkoutsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();

    expect(find.text('No workouts match your search.'), findsOneWidget);
  });

  testWidgets('tapping the refresh icon calls refresh on the notifier', (tester) async {
    var refreshed = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutsProvider.overrideWith(() => _RecordingWorkoutsNotifier(() => refreshed = true)),
        ],
        child: const MaterialApp(home: WorkoutsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    expect(refreshed, isTrue);
  });
}
