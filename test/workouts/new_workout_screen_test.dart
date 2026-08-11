import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/workouts/models/workout.dart';
import 'package:nomorex/features/workouts/providers/workouts_provider.dart';
import 'package:nomorex/features/workouts/screens/new_workout_screen.dart';

class _StubWorkoutsNotifier extends WorkoutsNotifier {
  _StubWorkoutsNotifier(this.onCreateWorkout);
  final Future<String> Function({
    required String title,
    String? notes,
    required bool isPublic,
  }) onCreateWorkout;

  @override
  Future<List<Workout>> build() async => const [];

  @override
  Future<String> createWorkout({
    String title = 'New Workout',
    String? notes,
    bool isPublic = false,
  }) {
    return onCreateWorkout(title: title, notes: notes, isPublic: isPublic);
  }
}

void main() {
  testWidgets('rendering the screen does not create a workout', (tester) async {
    var called = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutsProvider.overrideWith(
            () => _StubWorkoutsNotifier(({required title, notes, required isPublic}) async {
              called = true;
              return 'new-id';
            }),
          ),
          nextWorkoutNameProvider.overrideWith((ref) async => 'Workout 3'),
        ],
        child: const MaterialApp(home: NewWorkoutScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(called, isFalse);
  });

  testWidgets('tapping Save with a blank title falls back to the default name',
      (tester) async {
    String? capturedTitle;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutsProvider.overrideWith(
            () => _StubWorkoutsNotifier(({required title, notes, required isPublic}) async {
              capturedTitle = title;
              return 'new-id';
            }),
          ),
          nextWorkoutNameProvider.overrideWith((ref) async => 'Workout 3'),
        ],
        child: const MaterialApp(home: NewWorkoutScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(capturedTitle, 'Workout 3');
  });

  testWidgets('tapping Save with a title creates the workout with entered fields',
      (tester) async {
    String? capturedTitle;
    String? capturedNotes;
    bool? capturedIsPublic;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutsProvider.overrideWith(
            () => _StubWorkoutsNotifier(({required title, notes, required isPublic}) async {
              capturedTitle = title;
              capturedNotes = notes;
              capturedIsPublic = isPublic;
              return 'new-id';
            }),
          ),
          nextWorkoutNameProvider.overrideWith((ref) async => 'Workout 3'),
        ],
        child: const MaterialApp(home: NewWorkoutScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '  Heavy Day  ');
    await tester.enterText(find.byType(TextFormField).at(1), 'Build to a heavy triple');
    await tester.tap(find.byType(Switch));
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(capturedTitle, 'Heavy Day');
    expect(capturedNotes, 'Build to a heavy triple');
    expect(capturedIsPublic, isTrue);
  });
}
