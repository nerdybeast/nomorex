import '../models/workout_exercise.dart';
import '../models/workout_set.dart';

/// The exercise id whose 1RM a set's percentage should resolve against:
/// the set's own [WorkoutSet.basisExerciseId] if one was chosen, otherwise
/// the exercise the set belongs to (today's only behavior).
String resolveBasisExerciseId(WorkoutSet set, WorkoutExercise exercise) =>
    set.basisExerciseId ?? exercise.exerciseId;

/// Resolves a set's working weight in kg.
///
/// - `absolute` mode returns [absoluteWeightKg] (the user typed a fixed load).
/// - `percentage` mode returns `percentage/100 * oneRepMaxKg`, or `null` when
///   the user has no recorded 1-rep max for the lift.
double? resolveSetWeightKg({
  required String weightMode,
  double? percentage,
  double? absoluteWeightKg,
  double? oneRepMaxKg,
}) {
  if (weightMode == 'absolute') return absoluteWeightKg;
  if (weightMode == 'percentage') {
    if (oneRepMaxKg == null || percentage == null) return null;
    return percentage / 100 * oneRepMaxKg;
  }
  return null;
}
