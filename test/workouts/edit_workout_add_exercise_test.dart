import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/exercises/models/exercise.dart';
import 'package:nomorex/features/exercises/providers/exercises_provider.dart';
import 'package:nomorex/features/exercises/providers/recent_exercises_provider.dart';
import 'package:nomorex/features/exercises/widgets/exercise_picker_sheet.dart';
import 'package:nomorex/features/profile/providers/profile_provider.dart';
import 'package:nomorex/features/workouts/models/workout.dart';
import 'package:nomorex/features/workouts/providers/workout_detail_provider.dart';
import 'package:nomorex/features/workouts/screens/edit_workout_screen.dart';

/// Feeds the exercises list from a caller-controlled future so the test can
/// decide exactly when loading completes (before vs. after the dialog opens).
class _TestExercisesNotifier extends ExercisesNotifier {
  _TestExercisesNotifier(this._future, {this.onAddCustom});
  final Future<List<Exercise>> _future;
  final void Function(String name)? onAddCustom;
  @override
  Future<List<Exercise>> build() => _future;

  // The real one finds by name first and only then creates; keep that so the
  // test proves the picker goes through it.
  @override
  Future<Exercise> ensureExerciseByName(String name) async {
    for (final e in await future) {
      if (e.name.toLowerCase() == name.trim().toLowerCase()) return e;
    }
    return addCustomExercise(name.trim());
  }

  @override
  Future<Exercise> addCustomExercise(String name) async {
    onAddCustom?.call(name);
    return Exercise(id: 'new-custom', name: name, isPredefined: false);
  }
}

class _TestWorkoutDetailNotifier extends WorkoutDetailNotifier {
  _TestWorkoutDetailNotifier(this._workout, {this.onAddExercise, this.fail = false});
  final Workout _workout;
  final void Function(String exerciseId)? onAddExercise;
  final bool fail;
  @override
  Future<Workout> build(String workoutId) async => _workout;

  @override
  Future<void> addExercise(String exerciseId) async {
    if (fail) throw Exception('offline');
    onAddExercise?.call(exerciseId);
  }
}

final _workout = Workout(
  id: 'w1',
  userId: 'u1',
  title: 'Day 1',
  date: DateTime(2026, 7, 5),
  updatedAt: DateTime(2026, 7, 5),
  workoutGroupId: 'g1',
);

const _catalog = [
  Exercise(id: 'e1', name: 'Bench Press', isPredefined: true),
  Exercise(id: 'e2', name: 'Snatch', isPredefined: true),
  Exercise(id: 'e3', name: 'Snatch Pull', isPredefined: true),
  Exercise(id: 'e4', name: 'Power Snatch', isPredefined: true),
  Exercise(id: 'e5', name: 'Dude Pulls', isPredefined: false, userId: 'u1'),
];

Future<void> _pumpEditor(
  WidgetTester tester, {
  Future<List<Exercise>>? exercises,
  List<String> recent = const [],
  void Function(String name)? onAddCustom,
  void Function(String exerciseId)? onAddExercise,
  bool failAdd = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        exercisesProvider.overrideWith(
          () => _TestExercisesNotifier(exercises ?? Future.value(_catalog), onAddCustom: onAddCustom),
        ),
        recentExerciseIdsProvider.overrideWith((ref) async => recent),
        workoutDetailProvider('w1').overrideWith(
          () => _TestWorkoutDetailNotifier(_workout, onAddExercise: onAddExercise, fail: failAdd),
        ),
        unitPreferenceProvider.overrideWithValue('kg'),
      ],
      child: const MaterialApp(home: EditWorkoutScreen(workoutId: 'w1')),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openPicker(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('edit_workout_add_exercise')));
  await tester.pumpAndSettle();
}

final _search = find.byKey(const Key('exercise_picker_search'));

void main() {
  testWidgets('the picker shows exercises that finish loading after it opens', (tester) async {
    final completer = Completer<List<Exercise>>();
    await _pumpEditor(tester, exercises: completer.future);
    await _openPicker(tester);
    expect(find.byKey(const Key('exercise_picker_loading')), findsOneWidget);

    completer.complete(_catalog);
    await tester.pumpAndSettle();
    await tester.enterText(_search, 'Bench');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('exercise_picker_row_e1')), findsOneWidget);
  });

  testWidgets('lists Recent first, then every exercise A–Z', (tester) async {
    await _pumpEditor(tester, recent: const ['e3', 'gone', 'e1']);
    await _openPicker(tester);

    expect(find.text('RECENT'), findsOneWidget);
    expect(find.text('ALL EXERCISES'), findsOneWidget);
    final recentTop = tester.getTopLeft(find.byKey(const ValueKey('exercise_picker_row_e3')).first).dy;
    final allLabel = tester.getTopLeft(find.text('ALL EXERCISES')).dy;
    expect(recentTop, lessThan(allLabel));
    // A recent id missing from the catalog is skipped, not shown blank.
    expect(find.byKey(const ValueKey('exercise_picker_row_gone')), findsNothing);
  });

  testWidgets('search puts names that start with the query first', (tester) async {
    final results = searchExercises(_catalog, 'snatch');
    expect(results.matches.map((e) => e.name), ['Snatch', 'Snatch Pull', 'Power Snatch']);
    expect(results.exact?.id, 'e2');
  });

  testWidgets('tapping an exercise saves it and closes the picker', (tester) async {
    String? added;
    await _pumpEditor(tester, onAddExercise: (id) => added = id);
    await _openPicker(tester);
    await tester.enterText(_search, 'pull');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('exercise_picker_row_e3')));
    await tester.pumpAndSettle();

    expect(added, 'e3');
    expect(find.byType(ExercisePickerPanel), findsNothing);
  });

  testWidgets('an exact name match offers no "Create" row', (tester) async {
    await _pumpEditor(tester);
    await _openPicker(tester);
    await tester.enterText(_search, 'snatch pull');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exercise_picker_create')), findsNothing);
  });

  testWidgets('a new name is created from the results and saved', (tester) async {
    String? createdName;
    String? added;
    await _pumpEditor(
      tester,
      onAddCustom: (name) => createdName = name,
      onAddExercise: (id) => added = id,
    );
    await _openPicker(tester);
    await tester.enterText(_search, 'Tall Clean');
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Create exercise Tall Clean'), findsOneWidget);
    await tester.tap(find.byKey(const Key('exercise_picker_create')));
    await tester.pumpAndSettle();

    expect(createdName, 'Tall Clean');
    expect(added, 'new-custom');
    expect(find.byType(ExercisePickerPanel), findsNothing);
  });

  testWidgets('a failed save keeps the picker open and says so', (tester) async {
    await _pumpEditor(tester, failAdd: true);
    await _openPicker(tester);
    await tester.tap(find.byKey(const ValueKey('exercise_picker_row_e1')).first);
    await tester.pumpAndSettle();

    expect(find.byType(ExercisePickerPanel), findsOneWidget);
    expect(find.byKey(const Key('exercise_picker_error')), findsOneWidget);
    expect(find.textContaining("Couldn't add Bench Press"), findsOneWidget);
  });
}
