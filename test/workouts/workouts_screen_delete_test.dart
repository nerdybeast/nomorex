import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/workouts/models/workout.dart';
import 'package:nomorex/features/workouts/providers/workouts_provider.dart';
import 'package:nomorex/features/workouts/screens/workouts_screen.dart';

class _RecordingWorkoutsNotifier extends WorkoutsNotifier {
  _RecordingWorkoutsNotifier(this._workouts, {this.onDelete});
  final List<Workout> _workouts;
  final void Function(String id)? onDelete;

  @override
  Future<List<Workout>> build() async => _workouts;

  @override
  Future<void> deleteWorkout(String id) async {
    onDelete?.call(id);
  }
}

void main() {
  final workout = Workout(
    id: 'w1',
    userId: 'u1',
    title: 'Push Day',
    date: DateTime(2026, 7, 1),
    updatedAt: DateTime(2026, 7, 1),
    workoutGroupId: 'w1',
  );

  testWidgets('selecting Delete opens a confirmation dialog', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutsProvider.overrideWith(() => _RecordingWorkoutsNotifier([workout])),
        ],
        child: const MaterialApp(home: WorkoutsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete workout?'), findsOneWidget);
    expect(find.text('This permanently deletes "Push Day" and all of its exercises and sets.'),
        findsOneWidget);
  });

  testWidgets('canceling the dialog leaves deleteWorkout uncalled', (tester) async {
    String? deletedId;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutsProvider.overrideWith(
            () => _RecordingWorkoutsNotifier([workout], onDelete: (id) => deletedId = id),
          ),
        ],
        child: const MaterialApp(home: WorkoutsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Cancel'),
    ));
    await tester.pumpAndSettle();

    expect(deletedId, isNull);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('confirming the dialog calls deleteWorkout with the right id', (tester) async {
    String? deletedId;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutsProvider.overrideWith(
            () => _RecordingWorkoutsNotifier([workout], onDelete: (id) => deletedId = id),
          ),
        ],
        child: const MaterialApp(home: WorkoutsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // The dialog's confirm button shares the label 'Delete' with the popup
    // menu item that's still technically in the tree behind it — scope to
    // the AlertDialog to disambiguate.
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Delete'),
    ));
    await tester.pumpAndSettle();

    expect(deletedId, 'w1');
  });
}
