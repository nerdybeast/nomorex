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
    int? dayOffset,
    this.isRestDay = false,
    this.notes,
    this.exercises = const [],
  }) : dayOffset = dayOffset ?? position;

  final String id;
  final String programWeekId;
  final int dayNumber;
  final String title;
  final bool isRestDay;
  final String? notes;
  final int position;

  /// Days from a run's start date to this day's date: 7 × its week's index
  /// plus its place in the week, both 0-based (see `programDayDate`). Set by
  /// [ProgramWeek.fromJson]; a day built without one (tests) uses [position].
  final int dayOffset;
  final List<ProgramExercise> exercises;

  factory ProgramDay.fromJson(Map<String, dynamic> json, {int? dayOffset}) {
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
      dayOffset: dayOffset,
      exercises: exercises,
    );
  }
}
