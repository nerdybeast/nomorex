import 'program_set.dart';

/// Template equivalent of [WorkoutExercise] — same shape minus `workoutId`,
/// plus `programDayId`.
class ProgramExercise {
  const ProgramExercise({
    required this.id,
    required this.programDayId,
    required this.exerciseId,
    required this.exerciseName,
    required this.position,
    this.notes,
    this.sets = const [],
  });

  final String id;
  final String programDayId;
  final String exerciseId;
  final String exerciseName;
  final int position;
  final String? notes;
  final List<ProgramSet> sets;

  factory ProgramExercise.fromJson(Map<String, dynamic> json) {
    final exerciseMap = json['exercises'] as Map<String, dynamic>?;
    final rawSets = (json['program_sets'] as List?) ?? const [];
    final sets = rawSets
        .map((e) => ProgramSet.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    return ProgramExercise(
      id: json['id'] as String,
      programDayId: json['program_day_id'] as String,
      exerciseId: json['exercise_id'] as String,
      exerciseName: exerciseMap?['name'] as String? ?? '',
      position: json['position'] as int,
      notes: json['notes'] as String?,
      sets: sets,
    );
  }
}
