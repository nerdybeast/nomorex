import 'workout_set.dart';

class WorkoutExercise {
  const WorkoutExercise({
    required this.id,
    required this.workoutId,
    required this.exerciseId,
    required this.exerciseName,
    required this.position,
    this.notes,
    this.sets = const [],
  });

  final String id;
  final String workoutId;
  final String exerciseId;
  final String exerciseName;
  final int position;
  final String? notes;
  final List<WorkoutSet> sets;

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) {
    final exerciseMap = json['exercises'] as Map<String, dynamic>?;
    final rawSets = (json['workout_sets'] as List?) ?? const [];
    final sets = rawSets
        .map((e) => WorkoutSet.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    return WorkoutExercise(
      id: json['id'] as String,
      workoutId: json['workout_id'] as String,
      exerciseId: json['exercise_id'] as String,
      exerciseName: exerciseMap?['name'] as String? ?? '',
      position: json['position'] as int,
      notes: json['notes'] as String?,
      sets: sets,
    );
  }
}
