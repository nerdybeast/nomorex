import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/workout.dart';
import '../models/workout_exercise.dart';
import '../models/workout_set.dart';

/// The copy-attribution columns to carry onto a new workout created *from*
/// [source] (duplicate, repeat, the next instance after finishing), so a copy
/// of another user's workout stays a copy — credited and unshareable — however
/// it's reused. Empty for the user's own workouts.
Map<String, dynamic> copyAttributionColumns(Workout source) {
  if (!source.isCopy) return const {};
  return {
    'is_copy': true,
    'copied_from_user_id': source.copiedFromUserId,
    'copied_from_display_name': source.copiedFromDisplayName,
    'copied_from_workout_id': source.copiedFromWorkoutId,
    'copied_from_program_id': source.copiedFromProgramId,
  };
}

/// Deep-copies [sourceExercises] (and their sets) onto [targetWorkoutId].
/// Copied sets reset completed/actual fields by omitting those columns, so
/// the insert falls back to their DB defaults. Shared by
/// [WorkoutsNotifier.duplicateWorkout] and [WorkoutDetailNotifier.repeatWorkout].
Future<void> copyWorkoutContents(
  SupabaseClient db, {
  required String userId,
  required List<WorkoutExercise> sourceExercises,
  required String targetWorkoutId,
}) async {
  for (final ex in sourceExercises) {
    final newEx = await db.from('workout_exercises').insert({
      'workout_id': targetWorkoutId,
      'user_id': userId,
      'exercise_id': ex.exerciseId,
      'position': ex.position,
      if (ex.notes != null) 'notes': ex.notes,
    }).select('id').single();
    final newExId = newEx['id'] as String;

    if (ex.sets.isEmpty) continue;
    await db.from('workout_sets').insert([
      for (final s in ex.sets)
        copiedSetRow(s, workoutExerciseId: newExId, userId: userId),
    ]);
  }
}

/// The `workout_sets` insert for a copy of [source]: its prescription
/// (targets, load, basis, note) only. Completed/actual fields are omitted so
/// they fall back to their DB defaults on the new row.
Map<String, dynamic> copiedSetRow(
  WorkoutSet source, {
  required String workoutExerciseId,
  required String userId,
}) =>
    {
      'workout_exercise_id': workoutExerciseId,
      'user_id': userId,
      'position': source.position,
      'target_reps': source.targetReps,
      if (source.targetRepsMax != null) 'target_reps_max': source.targetRepsMax,
      'weight_mode': source.weightMode,
      'percentage': source.percentage,
      'percentage_max': ?source.percentageMax,
      'rpe_min': ?source.rpeMin,
      'rpe_max': ?source.rpeMax,
      'absolute_weight_kg': source.absoluteWeightKg,
      'basis_exercise_id': source.basisExerciseId,
      'note': source.note,
    };
