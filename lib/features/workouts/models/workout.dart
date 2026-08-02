import 'workout_exercise.dart';

class Workout {
  const Workout({
    required this.id,
    required this.userId,
    required this.title,
    required this.date,
    required this.updatedAt,
    this.notes,
    this.exercises = const [],
    this.isPublic = false,
  });

  final String id;
  final String userId;
  final String title;
  final DateTime date;
  final String? notes;
  final List<WorkoutExercise> exercises;
  final bool isPublic;
  final DateTime updatedAt;

  factory Workout.fromJson(Map<String, dynamic> json) {
    final rawExercises = (json['workout_exercises'] as List?) ?? const [];
    final exercises = rawExercises
        .map((e) => WorkoutExercise.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    return Workout(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      date: DateTime.parse(json['date'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      notes: json['notes'] as String?,
      exercises: exercises,
      isPublic: (json['is_public'] as bool?) ?? false,
    );
  }
}
