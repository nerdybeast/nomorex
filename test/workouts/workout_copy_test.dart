import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/core/utils/copy_errors.dart';
import 'package:nomorex/features/exercises/models/exercise.dart';
import 'package:nomorex/features/exercises/providers/exercises_provider.dart';
import 'package:nomorex/features/profile/providers/profile_provider.dart';
import 'package:nomorex/features/workouts/models/workout.dart';
import 'package:nomorex/features/workouts/models/workout_exercise.dart';
import 'package:nomorex/features/workouts/models/workout_set.dart';
import 'package:nomorex/features/workouts/providers/finished_workouts_provider.dart';
import 'package:nomorex/features/workouts/providers/one_rep_max_provider.dart';
import 'package:nomorex/features/workouts/providers/workout_detail_provider.dart';
import 'package:nomorex/features/workouts/providers/workouts_provider.dart';
import 'package:nomorex/features/workouts/screens/edit_workout_screen.dart';
import 'package:nomorex/features/workouts/screens/workout_detail_screen.dart';
import 'package:nomorex/features/workouts/screens/workouts_screen.dart';
import 'package:nomorex/features/workouts/utils/workout_copier.dart';
import 'package:nomorex/shared/models/one_rep_max.dart';

class _StubWorkoutsNotifier extends WorkoutsNotifier {
  _StubWorkoutsNotifier(this._workouts);
  final List<Workout> _workouts;
  @override
  Future<List<Workout>> build() async => _workouts;
}

class _StubWorkoutDetailNotifier extends WorkoutDetailNotifier {
  _StubWorkoutDetailNotifier(this._workout, {this.onUpdateVisibility});
  final Workout _workout;
  final void Function(bool)? onUpdateVisibility;
  @override
  Future<Workout> build(String workoutId) async => _workout;
  @override
  Future<void> updateVisibility(bool isPublic) async => onUpdateVisibility?.call(isPublic);
}

class _StubFinishedWorkoutsNotifier extends FinishedWorkoutsNotifier {
  @override
  Future<List<Workout>> build() async => const [];
}

class _StubExercisesNotifier extends ExercisesNotifier {
  @override
  Future<List<Exercise>> build() async => const [];
}

/// A saved copy of BeastModeB's workout: one Front Squat set programmed off
/// *their* Back Squat ('their-bs' — an id the viewer doesn't own).
Workout _copiedWorkout({bool isCopy = true, bool isImported = false}) => Workout(
      id: 'w1',
      userId: 'viewer',
      title: 'Accessory Grinder',
      date: DateTime(2026, 10, 12),
      updatedAt: DateTime(2026, 10, 12),
      workoutGroupId: 'g1',
      isCopy: isCopy,
      isImported: isImported,
      copiedFromUserId: isCopy && !isImported ? 'author' : null,
      copiedFromDisplayName: isCopy && !isImported ? 'BeastModeB' : null,
      copiedFromWorkoutId: isCopy && !isImported ? 'w0' : null,
      exercises: const [
        WorkoutExercise(
          id: 'we1',
          workoutId: 'w1',
          exerciseId: 'fs',
          exerciseName: 'Front Squat',
          position: 0,
          sets: [
            WorkoutSet(
              id: 's1',
              workoutExerciseId: 'we1',
              position: 0,
              weightMode: 'percentage',
              targetReps: 3,
              percentage: 70,
              basisExerciseId: 'their-bs',
              basisExerciseName: 'Back Squat',
            ),
          ],
        ),
      ],
    );

Future<void> _pumpDetail(
  WidgetTester tester,
  Workout workout, {
  Map<String, OneRepMax> byName = const {},
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workoutDetailProvider('w1').overrideWith(() => _StubWorkoutDetailNotifier(workout)),
        oneRepMaxProvider.overrideWith((ref) async => {}),
        oneRepMaxByNameProvider.overrideWith((ref) async => byName),
        exercisesProvider.overrideWith(() => _StubExercisesNotifier()),
        finishedWorkoutsProvider.overrideWith(() => _StubFinishedWorkoutsNotifier()),
        unitPreferenceProvider.overrideWithValue('kg'),
      ],
      child: const MaterialApp(home: WorkoutDetailScreen(workoutId: 'w1')),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('a workout derived from an import stays marked imported', () {
    final columns = copyAttributionColumns(_copiedWorkout(isImported: true));

    expect(columns['is_copy'], isTrue);
    expect(columns['is_imported'], isTrue);
    expect(columns['copied_from_user_id'], isNull);
  });

  test('a workout derived from a Community copy is not marked imported', () {
    expect(copyAttributionColumns(_copiedWorkout())['is_imported'], isFalse);
  });

  test('a workout the user created derives no attribution', () {
    expect(copyAttributionColumns(_copiedWorkout(isCopy: false)), isEmpty);
  });

  testWidgets('an imported workout is badged Imported on its list card', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutsProvider.overrideWith(
            () => _StubWorkoutsNotifier([_copiedWorkout(isImported: true)]),
          ),
        ],
        child: const MaterialApp(home: WorkoutsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Imported'), findsOneWidget);
  });

  testWidgets('the Public switch on an import is disabled and says why', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutDetailProvider('w1').overrideWith(
            () => _StubWorkoutDetailNotifier(_copiedWorkout(isImported: true)),
          ),
          exercisesProvider.overrideWith(() => _StubExercisesNotifier()),
          unitPreferenceProvider.overrideWithValue('kg'),
        ],
        child: const MaterialApp(home: EditWorkoutScreen(workoutId: 'w1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    expect(find.text(kImportNotShareableMessage), findsOneWidget);
    expect(find.text(kCopyNotShareableMessage), findsNothing);
  });

  testWidgets('a copied workout is badged on its Workouts list card', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutsProvider.overrideWith(() => _StubWorkoutsNotifier([_copiedWorkout()])),
        ],
        child: const MaterialApp(home: WorkoutsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('copied_from_badge')), findsOneWidget);
    expect(find.text('Copied from BeastModeB'), findsOneWidget);
  });

  testWidgets('a workout the user created has no badge on its card', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutsProvider.overrideWith(
            () => _StubWorkoutsNotifier([_copiedWorkout(isCopy: false)]),
          ),
        ],
        child: const MaterialApp(home: WorkoutsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Copied from'), findsNothing);
  });

  testWidgets('a copied workout is badged on its detail screen', (tester) async {
    await _pumpDetail(tester, _copiedWorkout());

    expect(find.text('Copied from BeastModeB'), findsOneWidget);
  });

  testWidgets(
    "a copy's percentage set resolves against the VIEWER's 1RM by name (FR-020)",
    (tester) async {
      // The basis id belongs to the author, so only the name lookup can hit.
      await _pumpDetail(
        tester,
        _copiedWorkout(),
        byName: const {'back squat': OneRepMax.measured(100)},
      );

      expect(find.textContaining('70 kg'), findsOneWidget);
      expect(find.text('set PR'), findsNothing);
    },
  );

  testWidgets("a copy's percentage set with no viewer 1RM offers set PR, not zero",
      (tester) async {
    await _pumpDetail(tester, _copiedWorkout());

    expect(find.text('set PR'), findsOneWidget);
    expect(find.textContaining('0 kg'), findsNothing);
  });

  testWidgets('the Public switch is disabled on a copy, with the reason', (tester) async {
    var toggled = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutDetailProvider('w1').overrideWith(
            () => _StubWorkoutDetailNotifier(
              _copiedWorkout(),
              onUpdateVisibility: (_) => toggled = true,
            ),
          ),
          exercisesProvider.overrideWith(() => _StubExercisesNotifier()),
          unitPreferenceProvider.overrideWithValue('kg'),
        ],
        child: const MaterialApp(home: EditWorkoutScreen(workoutId: 'w1')),
      ),
    );
    await tester.pumpAndSettle();

    final publicSwitch = tester.widget<Switch>(find.byType(Switch));
    expect(publicSwitch.onChanged, isNull);
    expect(find.text(kCopyNotShareableMessage), findsOneWidget);

    await tester.tap(find.byType(Switch), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(toggled, isFalse);
  });
}
