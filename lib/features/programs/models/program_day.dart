import 'program_exercise.dart';

/// One planned session within a program week. Maps 1:1 to a future
/// `workouts` row once the program is started.
class ProgramDay {
  const ProgramDay({
    required this.id,
    required this.programWeekId,
    required this.dayNumber,
    required this.title,
    required this.position,
    this.isRestDay = false,
    this.notes,
    this.exercises = const [],
  });

  final String id;
  final String programWeekId;
  final int dayNumber;
  final String title;
  final bool isRestDay;
  final String? notes;
  final int position;
  final List<ProgramExercise> exercises;

  factory ProgramDay.fromJson(Map<String, dynamic> json) {
    final rawExercises = (json['program_exercises'] as List?) ?? const [];
    final exercises = rawExercises
        .map((e) => ProgramExercise.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    return ProgramDay(
      id: json['id'] as String,
      programWeekId: json['program_week_id'] as String,
      dayNumber: json['day_number'] as int,
      title: json['title'] as String,
      isRestDay: (json['is_rest_day'] as bool?) ?? false,
      notes: json['notes'] as String?,
      position: json['position'] as int,
      exercises: exercises,
    );
  }
}
