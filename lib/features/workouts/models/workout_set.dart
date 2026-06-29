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

  factory WorkoutSet.fromJson(Map<String, dynamic> json) => WorkoutSet(
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
      );
}
