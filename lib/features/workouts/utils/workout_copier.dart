import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/workout.dart';
import '../models/workout_exercise.dart';

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
        {
          'workout_exercise_id': newExId,
          'user_id': userId,
          'position': s.position,
          'target_reps': s.targetReps,
          'weight_mode': s.weightMode,
          'percentage': s.percentage,
          'absolute_weight_kg': s.absoluteWeightKg,
          'basis_exercise_id': s.basisExerciseId,
          'note': s.note,
        },
    ]);
  }
}
