import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/workouts/models/workout.dart';
import 'package:nomorex/features/workouts/providers/workouts_provider.dart';
import 'package:nomorex/features/workouts/screens/workouts_screen.dart';
import 'package:nomorex/shared/widgets/archived_pill.dart';

class _RecordingWorkoutsNotifier extends WorkoutsNotifier {
  _RecordingWorkoutsNotifier(this._workouts, {this.calls});
  final List<Workout> _workouts;
  final List<String>? calls;

  @override
  Future<List<Workout>> build() async => _workouts;

  @override
  Future<void> archiveWorkout(Workout workout) async => calls?.add('archive ${workout.id}');

  @override
  Future<void> restoreWorkout(Workout workout) async => calls?.add('restore ${workout.id}');

  @override
  Future<void> deleteWorkoutPermanently(Workout workout) async =>
      calls?.add('delete ${workout.id}');
}

class _ArchivedWorkoutsNotifier extends ArchivedWorkoutsNotifier {
  _ArchivedWorkoutsNotifier(this._workouts);
  final List<Workout> _workouts;

  @override
  Future<List<Workout>> build() async => _workouts;
}

Workout _workout(String id, {String status = 'not_started', bool archived = false}) => Workout(
      id: id,
      userId: 'u1',
      title: 'Push Day $id',
      date: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 1),
      workoutGroupId: id,
      status: status,
      isArchived: archived,
      archivedAt: archived ? DateTime(2026, 10, 26) : null,
    );

Widget _app({
  List<Workout> active = const [],
  List<Workout> archived = const [],
  List<String>? calls,
}) {
  return ProviderScope(
    overrides: [
      workoutsProvider.overrideWith(() => _RecordingWorkoutsNotifier(active, calls: calls)),
      archivedWorkoutsProvider.overrideWith(() => _ArchivedWorkoutsNotifier(archived)),
    ],
    child: const MaterialApp(home: WorkoutsScreen()),
  );
}

Future<void> _openArchivedTab(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('tab_archived')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tabs show the active and archived counts', (tester) async {
    await tester.pumpWidget(_app(
      active: [_workout('a'), _workout('b')],
      archived: [_workout('c', archived: true)],
    ));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byKey(const Key('tab_active')), matching: find.text('2')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byKey(const Key('tab_archived')), matching: find.text('1')),
      findsOneWidget,
    );
  });

  testWidgets('the active row menu offers Archive instead of Delete', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(_app(active: [_workout('a')], calls: calls));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsNothing);

    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    expect(calls, ['archive a']);
  });

  testWidgets('a workout mid-session cannot be archived', (tester) async {
    await tester.pumpWidget(_app(active: [_workout('a', status: 'in_progress')]));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Archive'), findsNothing);
    expect(find.text('Edit'), findsOneWidget);
  });

  testWidgets('an archived row shows the pill, its date and a Restore button', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(_app(archived: [_workout('c', archived: true)], calls: calls));
    await tester.pumpAndSettle();
    await _openArchivedTab(tester);

    expect(find.byType(ArchivedPill), findsOneWidget);
    expect(find.text('Archived Oct 26, 2026'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);

    await tester.tap(find.byKey(const Key('archived_restore')));
    await tester.pumpAndSettle();
    expect(calls, ['restore c']);
  });

  testWidgets('Delete permanently confirms before deleting', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(_app(archived: [_workout('c', archived: true)], calls: calls));
    await tester.pumpAndSettle();
    await _openArchivedTab(tester);

    await tester.tap(find.byKey(const Key('archived_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();

    expect(find.text('Delete workout permanently?'), findsOneWidget);
    expect(
      find.text('This deletes "Push Day c" and all of its logged sessions. This can\'t be undone.'),
      findsOneWidget,
    );

    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Cancel')));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);

    await tester.tap(find.byKey(const Key('archived_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete')));
    await tester.pumpAndSettle();
    expect(calls, ['delete c']);
  });

  testWidgets('an empty Archived tab invites archiving', (tester) async {
    await tester.pumpWidget(_app(active: [_workout('a')]));
    await tester.pumpAndSettle();
    await _openArchivedTab(tester);

    expect(find.text('No archived workouts'), findsOneWidget);
    expect(find.text('Workouts you archive show up here.'), findsOneWidget);
  });
}
