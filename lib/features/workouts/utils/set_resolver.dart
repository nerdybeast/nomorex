import '../models/workout_exercise.dart';
import '../models/workout_set.dart';

/// The exercise id whose 1RM a set's percentage should resolve against:
/// the set's own [WorkoutSet.basisExerciseId] if one was chosen, otherwise
/// the exercise the set belongs to (today's only behavior).
String resolveBasisExerciseId(WorkoutSet set, WorkoutExercise exercise) =>
    set.basisExerciseId ?? exercise.exerciseId;

/// The viewer's 1RM (kg) for a set's basis lift, or null if they have none.
///
/// Falls back from exercise id to exercise name because the id is only
/// meaningful within one user's catalog: on someone else's public workout the
/// set points at *their* exercise row, so a viewer who has recorded a PR for
/// the same lift — under their own id — would otherwise look like they had no
/// 1RM at all. Names are compared case-insensitively.
double? lookupOneRepMaxKg({
  required String basisExerciseId,
  required String basisExerciseName,
  required Map<String, double> byExerciseId,
  required Map<String, double> byExerciseName,
}) {
  return byExerciseId[basisExerciseId] ??
      byExerciseName[basisExerciseName.toLowerCase()];
}

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
