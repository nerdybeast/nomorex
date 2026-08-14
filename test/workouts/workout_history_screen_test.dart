import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/workouts/models/workout.dart';
import 'package:nomorex/features/workouts/providers/finished_workouts_provider.dart';
import 'package:nomorex/features/workouts/screens/workout_history_screen.dart';

class _StubFinishedWorkoutsNotifier extends FinishedWorkoutsNotifier {
  _StubFinishedWorkoutsNotifier(this._workouts);
  final List<Workout> _workouts;
  @override
  Future<List<Workout>> build() async => _workouts;
}

Workout _finished({
  required String id,
  required String groupId,
  required String title,
  required DateTime finishedAt,
  Duration duration = const Duration(hours: 1),
  String? sessionNotes,
}) {
  return Workout(
    id: id,
    userId: 'u1',
    title: title,
    date: finishedAt,
    updatedAt: finishedAt,
    workoutGroupId: groupId,
    status: 'finished',
    startedAt: finishedAt.subtract(duration),
    finishedAt: finishedAt,
    sessionNotes: sessionNotes,
  );
}

void main() {
  testWidgets('shows an empty state when nothing has been completed yet', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          finishedWorkoutsProvider.overrideWith(() => _StubFinishedWorkoutsNotifier(const [])),
        ],
        child: const MaterialApp(home: WorkoutHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("You haven't completed any workouts yet."), findsOneWidget);
  });

  testWidgets('unfiltered: lists every completed workout, newest first', (tester) async {
    final workouts = [
      _finished(id: 'w2', groupId: 'g2', title: 'Pull Day', finishedAt: DateTime(2026, 8, 12)),
      _finished(id: 'w1', groupId: 'g1', title: 'Push Day', finishedAt: DateTime(2026, 8, 5)),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          finishedWorkoutsProvider.overrideWith(() => _StubFinishedWorkoutsNotifier(workouts)),
        ],
        child: const MaterialApp(home: WorkoutHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pull Day'), findsOneWidget);
    expect(find.text('Push Day'), findsOneWidget);
    expect(find.text('Filtering:'), findsNothing);
    expect(find.text('Clear filter'), findsNothing);

    // "Pull Day" (newer) should be laid out above "Push Day" (older).
    final pullTop = tester.getTopLeft(find.text('Pull Day')).dy;
    final pushTop = tester.getTopLeft(find.text('Push Day')).dy;
    expect(pullTop, lessThan(pushTop));
  });

  testWidgets('filtered by groupId: shows only matching completions, with a clear filter action',
      (tester) async {
    final workouts = [
      _finished(id: 'w1', groupId: 'g1', title: 'Push Day', finishedAt: DateTime(2026, 8, 12)),
      _finished(id: 'w1b', groupId: 'g1', title: 'Push Day', finishedAt: DateTime(2026, 8, 5)),
      _finished(id: 'w2', groupId: 'g2', title: 'Pull Day', finishedAt: DateTime(2026, 8, 10)),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          finishedWorkoutsProvider.overrideWith(() => _StubFinishedWorkoutsNotifier(workouts)),
        ],
        child: const MaterialApp(home: WorkoutHistoryScreen(initialGroupId: 'g1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Push Day'), findsNWidgets(2));
    expect(find.text('Pull Day'), findsNothing);
    expect(find.textContaining('Filtering: Push Day'), findsOneWidget);

    await tester.tap(find.text('Clear filter'));
    await tester.pumpAndSettle();

    expect(find.text('Push Day'), findsNWidgets(2));
    expect(find.text('Pull Day'), findsOneWidget);
    expect(find.textContaining('Filtering:'), findsNothing);
  });

  testWidgets('filtered with no matching completions shows the filtered empty state',
      (tester) async {
    final workouts = [
      _finished(id: 'w2', groupId: 'g2', title: 'Pull Day', finishedAt: DateTime(2026, 8, 10)),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          finishedWorkoutsProvider.overrideWith(() => _StubFinishedWorkoutsNotifier(workouts)),
        ],
        // No workout with groupId 'g1' remains finished (e.g. it was
        // discarded), so the filtered view has nothing to show even though
        // unfiltered history is non-empty.
        child: const MaterialApp(home: WorkoutHistoryScreen(initialGroupId: 'g1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No completed sessions of this workout yet.'), findsOneWidget);
  });

  testWidgets('shows completion date, duration, and typed notes for each entry',
      (tester) async {
    final workouts = [
      _finished(
        id: 'w1',
        groupId: 'g1',
        title: 'Push Day',
        finishedAt: DateTime(2026, 8, 12),
        duration: const Duration(hours: 1, minutes: 15, seconds: 30),
        sessionNotes: 'Felt strong today',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          finishedWorkoutsProvider.overrideWith(() => _StubFinishedWorkoutsNotifier(workouts)),
        ],
        child: const MaterialApp(home: WorkoutHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Completed'), findsOneWidget);
    expect(find.text('Duration: 01:15:30'), findsOneWidget);
    expect(find.text('Felt strong today'), findsOneWidget);
    expect(find.text('No Notes Provided'), findsNothing);
  });

  testWidgets('shows italicized "No Notes Provided" when no notes were entered',
      (tester) async {
    final workouts = [
      _finished(id: 'w1', groupId: 'g1', title: 'Push Day', finishedAt: DateTime(2026, 8, 12)),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          finishedWorkoutsProvider.overrideWith(() => _StubFinishedWorkoutsNotifier(workouts)),
        ],
        child: const MaterialApp(home: WorkoutHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final noNotes = tester.widget<Text>(find.text('No Notes Provided'));
    expect(noNotes.style?.fontStyle, FontStyle.italic);
  });
}
