import '../../../shared/models/editable_set_row.dart';

class WorkoutSet {
  const WorkoutSet({
    required this.id,
    required this.workoutExerciseId,
    required this.position,
    required this.weightMode,
    this.targetReps,
    this.percentage,
    this.absoluteWeightKg,
    this.note,
    this.completed = false,
    this.actualWeightKg,
    this.actualReps,
    this.basisExerciseId,
    this.basisExerciseName,
  });

  final String id;
  final String workoutExerciseId;
  final int position;
  final String weightMode; // 'percentage' | 'absolute'
  final int? targetReps;
  final double? percentage;
  final double? absoluteWeightKg;
  final String? note;
  final bool completed;
  final double? actualWeightKg;
  final int? actualReps;
  final String? basisExerciseId;
  final String? basisExerciseName;

  factory WorkoutSet.fromJson(Map<String, dynamic> json) {
    final basisExerciseMap = json['exercises'] as Map<String, dynamic>?;
    return WorkoutSet(
      id: json['id'] as String,
      workoutExerciseId: json['workout_exercise_id'] as String,
      position: json['position'] as int,
      weightMode: json['weight_mode'] as String,
      targetReps: json['target_reps'] as int?,
      percentage: (json['percentage'] as num?)?.toDouble(),
      absoluteWeightKg: (json['absolute_weight_kg'] as num?)?.toDouble(),
      note: json['note'] as String?,
      completed: (json['completed'] as bool?) ?? false,
      actualWeightKg: (json['actual_weight_kg'] as num?)?.toDouble(),
      actualReps: json['actual_reps'] as int?,
      basisExerciseId: json['basis_exercise_id'] as String?,
      basisExerciseName: basisExerciseMap?['name'] as String?,
    );
  }

  EditableSetRow toEditableRow() => EditableSetRow(
        id: id,
        targetReps: targetReps,
        weightMode: weightMode,
        percentage: percentage,
        absoluteWeightKg: absoluteWeightKg,
        basisExerciseId: basisExerciseId,
        basisExerciseName: basisExerciseName,
      );
}
