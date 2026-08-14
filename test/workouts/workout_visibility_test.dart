import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/profile/providers/profile_provider.dart';
import 'package:nomorex/features/workouts/models/workout.dart';
import 'package:nomorex/features/workouts/providers/workout_detail_provider.dart';
import 'package:nomorex/features/workouts/screens/edit_workout_screen.dart';

class _StubWorkoutDetailNotifier extends WorkoutDetailNotifier {
  _StubWorkoutDetailNotifier(
    this._workout, {
    this.onUpdateVisibility,
    this.onUpdateTitle,
    this.onUpdateDescription,
  });
  final Workout _workout;
  final void Function(bool isPublic)? onUpdateVisibility;
  final void Function(String title)? onUpdateTitle;
  final void Function(String? description)? onUpdateDescription;

  @override
  Future<Workout> build(String workoutId) async => _workout;

  @override
  Future<void> updateVisibility(bool isPublic) async {
    onUpdateVisibility?.call(isPublic);
  }

  @override
  Future<void> updateTitle(String title) async {
    onUpdateTitle?.call(title);
  }

  @override
  Future<void> updateDescription(String? description) async {
    onUpdateDescription?.call(description);
  }
}

void main() {
  testWidgets('toggling the Public switch calls updateVisibility with the flipped value',
      (tester) async {
    final workout = Workout(
      id: 'w1',
      userId: 'u1',
      title: 'Day 1',
      date: DateTime(2026, 7, 5),
      updatedAt: DateTime(2026, 7, 5),
      workoutGroupId: 'g1',
      isPublic: false,
    );
    bool? toggledTo;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutDetailProvider('w1').overrideWith(
            () => _StubWorkoutDetailNotifier(
              workout,
              onUpdateVisibility: (v) => toggledTo = v,
            ),
          ),
          unitPreferenceProvider.overrideWithValue('kg'),
        ],
        child: const MaterialApp(home: EditWorkoutScreen(workoutId: 'w1')),
      ),
    );
    await tester.pumpAndSettle();

    final switchWidget = tester.widget<Switch>(find.byType(Switch));
    expect(switchWidget.value, isFalse);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(toggledTo, isTrue);
  });

  testWidgets('submitting the Title field calls updateTitle with the trimmed value',
      (tester) async {
    final workout = Workout(
      id: 'w1',
      userId: 'u1',
      title: 'Day 1',
      date: DateTime(2026, 7, 5),
      updatedAt: DateTime(2026, 7, 5),
      workoutGroupId: 'g1',
    );
    String? updatedTitle;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutDetailProvider('w1').overrideWith(
            () => _StubWorkoutDetailNotifier(
              workout,
              onUpdateTitle: (v) => updatedTitle = v,
            ),
          ),
          unitPreferenceProvider.overrideWithValue('kg'),
        ],
        child: const MaterialApp(home: EditWorkoutScreen(workoutId: 'w1')),
      ),
    );
    await tester.pumpAndSettle();

    // The Title field is the first TextFormField on the screen (Description
    // is second); there are no exercises in this stub workout to add more.
    await tester.enterText(find.byType(TextFormField).at(0), '  Heavy Day  ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(updatedTitle, 'Heavy Day');
  });

  testWidgets('submitting a blank Title does not call updateTitle', (tester) async {
    final workout = Workout(
      id: 'w1',
      userId: 'u1',
      title: 'Day 1',
      date: DateTime(2026, 7, 5),
      updatedAt: DateTime(2026, 7, 5),
      workoutGroupId: 'g1',
    );
    var called = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutDetailProvider('w1').overrideWith(
            () => _StubWorkoutDetailNotifier(
              workout,
              onUpdateTitle: (_) => called = true,
            ),
          ),
          unitPreferenceProvider.overrideWithValue('kg'),
        ],
        child: const MaterialApp(home: EditWorkoutScreen(workoutId: 'w1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '   ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(called, isFalse);
  });

  testWidgets('submitting the Description field calls updateDescription', (tester) async {
    final workout = Workout(
      id: 'w1',
      userId: 'u1',
      title: 'Day 1',
      date: DateTime(2026, 7, 5),
      updatedAt: DateTime(2026, 7, 5),
      workoutGroupId: 'g1',
    );
    String? updatedDescription;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutDetailProvider('w1').overrideWith(
            () => _StubWorkoutDetailNotifier(
              workout,
              onUpdateDescription: (v) => updatedDescription = v,
            ),
          ),
          unitPreferenceProvider.overrideWithValue('kg'),
        ],
        child: const MaterialApp(home: EditWorkoutScreen(workoutId: 'w1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(1), 'Heavy squat day, build to a 3RM');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(updatedDescription, 'Heavy squat day, build to a 3RM');
  });
}
