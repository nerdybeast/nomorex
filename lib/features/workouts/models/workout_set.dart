import '../../../shared/models/editable_set_row.dart';

class WorkoutSet {
  const WorkoutSet({
    required this.id,
    required this.workoutExerciseId,
    required this.position,
    required this.weightMode,
    this.targetReps,
    this.targetRepsMax,
    this.percentage,
    this.percentageMax,
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
  /// Top of a rep range; null means a single rep count ([targetReps]).
  final int? targetRepsMax;
  final double? percentage;
  /// Top of a %1RM range; null means a single percentage.
  final double? percentageMax;
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
      targetRepsMax: json['target_reps_max'] as int?,
      percentage: (json['percentage'] as num?)?.toDouble(),
      percentageMax: (json['percentage_max'] as num?)?.toDouble(),
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
        targetRepsMax: targetRepsMax,
        weightMode: weightMode,
        percentage: percentage,
        percentageMax: percentageMax,
        absoluteWeightKg: absoluteWeightKg,
        basisExerciseId: basisExerciseId,
        basisExerciseName: basisExerciseName,
      );
}
