import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/workouts/models/workout_exercise.dart';
import 'package:nomorex/features/workouts/models/workout_set.dart';
import 'package:nomorex/features/workouts/utils/set_resolver.dart';
import 'package:nomorex/shared/models/one_rep_max.dart';

const _exercise = WorkoutExercise(
  id: 'we1',
  workoutId: 'w1',
  exerciseId: 'e1',
  exerciseName: 'Front Squat',
  position: 0,
);

void main() {
  test('absolute mode returns the absolute weight, ignoring 1RM', () {
    expect(
      resolveSetWeightKg(weightMode: 'absolute', absoluteWeightKg: 60, oneRepMaxKg: 100),
      60,
    );
  });

  test('percentage mode multiplies percentage against the 1RM', () {
    expect(
      resolveSetWeightKg(weightMode: 'percentage', percentage: 80, oneRepMaxKg: 100),
      80,
    );
  });

  test('percentage mode returns null when no 1RM is available', () {
    expect(
      resolveSetWeightKg(weightMode: 'percentage', percentage: 80, oneRepMaxKg: null),
      isNull,
    );
  });

  test('absolute mode returns null when no absolute weight set', () {
    expect(
      resolveSetWeightKg(weightMode: 'absolute', absoluteWeightKg: null, oneRepMaxKg: 100),
      isNull,
    );
  });

  test('resolveBasisExerciseId falls back to the owning exercise when unset', () {
    const set = WorkoutSet(
      id: 's1',
      workoutExerciseId: 'we1',
      position: 0,
      weightMode: 'percentage',
      percentage: 80,
    );
    expect(resolveBasisExerciseId(set, _exercise), 'e1');
  });

  test('resolveBasisExerciseId prefers an explicit basis exercise', () {
    const set = WorkoutSet(
      id: 's1',
      workoutExerciseId: 'we1',
      position: 0,
      weightMode: 'percentage',
      percentage: 80,
      basisExerciseId: 'e2',
    );
    expect(resolveBasisExerciseId(set, _exercise), 'e2');
  });

  group('lookupOneRepMax', () {
    test('prefers a match on exercise id', () {
      expect(
        lookupOneRepMax(
          basisExerciseId: 'e1',
          basisExerciseName: 'Front Squat',
          byExerciseId: const {'e1': OneRepMax.measured(100)},
          byExerciseName: const {'front squat': OneRepMax.measured(90)},
        )?.kg,
        100,
      );
    });

    test('falls back to the exercise name when the id is another user\'s', () {
      expect(
        lookupOneRepMax(
          basisExerciseId: 'owners-id',
          basisExerciseName: 'dude pulls',
          byExerciseId: const {'viewers-id': OneRepMax.measured(87)},
          byExerciseName: const {'dude pulls': OneRepMax.measured(87)},
        )?.kg,
        87,
      );
    });

    test('matches names case-insensitively', () {
      expect(
        lookupOneRepMax(
          basisExerciseId: 'owners-id',
          basisExerciseName: 'Dude Pulls',
          byExerciseId: const {},
          byExerciseName: const {'dude pulls': OneRepMax.measured(87)},
        )?.kg,
        87,
      );
    });

    test('returns null when neither the id nor the name is known', () {
      expect(
        lookupOneRepMax(
          basisExerciseId: 'e1',
          basisExerciseName: 'Front Squat',
          byExerciseId: const {},
          byExerciseName: const {},
        ),
        isNull,
      );
    });
  });

  group('lookupOneRepMax carries the measured/estimated distinction', () {
    test('reports a measured single as not estimated', () {
      final max = lookupOneRepMax(
        basisExerciseId: 'e1',
        basisExerciseName: 'Front Squat',
        byExerciseId: const {'e1': OneRepMax.measured(100)},
        byExerciseName: const {},
      );
      expect(max?.isEstimated, isFalse);
    });

    test('reports an inferred max as estimated', () {
      final max = lookupOneRepMax(
        basisExerciseId: 'e1',
        basisExerciseName: 'Front Squat',
        byExerciseId: const {'e1': OneRepMax.estimated(112.5)},
        byExerciseName: const {},
      );
      expect(max?.isEstimated, isTrue);
    });

    test('carries the flag through the name fallback too', () {
      final max = lookupOneRepMax(
        basisExerciseId: 'owners-id',
        basisExerciseName: 'Dude Pulls',
        byExerciseId: const {},
        byExerciseName: const {'dude pulls': OneRepMax.estimated(87)},
      );
      expect(max?.isEstimated, isTrue);
    });
  });
}
