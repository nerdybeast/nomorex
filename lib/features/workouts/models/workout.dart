import 'workout_exercise.dart';

class Workout {
  const Workout({
    required this.id,
    required this.userId,
    required this.title,
    required this.date,
    required this.updatedAt,
    required this.workoutGroupId,
    this.notes,
    this.exercises = const [],
    this.isPublic = false,
    this.programInstanceId,
    this.programDayId,
    this.status = 'not_started',
    this.startedAt,
    this.pausedAt,
    this.totalPausedSeconds = 0,
    this.finishedAt,
    this.sessionNotes,
    this.ownerDisplayName,
  });

  final String id;
  final String userId;

  /// Author's `profiles.display_name`, present only when the query embedded
  /// `profiles(display_name)` (the community reads do; the owner's own lists
  /// don't need it). Null both for "not selected" and "owner has no name set",
  /// so render it through `ownerDisplayName()` in core/utils/owner_name.dart.
  final String? ownerDisplayName;
  final String title;
  final DateTime date;
  final String? notes;
  final List<WorkoutExercise> exercises;
  final bool isPublic;
  final DateTime updatedAt;
  final String? programInstanceId;
  final String? programDayId;

  /// Shared across every completion of "the same" workout — set fresh on
  /// creation, carried forward when repeating a finished workout so history
  /// can be queried by this id. See repeatWorkout().
  final String workoutGroupId;

  /// 'not_started' | 'in_progress' | 'paused' | 'finished'.
  final String status;
  final DateTime? startedAt;
  final DateTime? pausedAt;
  final int totalPausedSeconds;
  final DateTime? finishedAt;
  final String? sessionNotes;

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
      workoutGroupId: json['workout_group_id'] as String,
      notes: json['notes'] as String?,
      exercises: exercises,
      isPublic: (json['is_public'] as bool?) ?? false,
      programInstanceId: json['program_instance_id'] as String?,
      programDayId: json['program_day_id'] as String?,
      status: json['status'] as String? ?? 'not_started',
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at'] as String) : null,
      pausedAt: json['paused_at'] != null ? DateTime.parse(json['paused_at'] as String) : null,
      totalPausedSeconds: (json['total_paused_seconds'] as int?) ?? 0,
      finishedAt:
          json['finished_at'] != null ? DateTime.parse(json['finished_at'] as String) : null,
      sessionNotes: json['session_notes'] as String?,
      ownerDisplayName: (json['profiles'] as Map<String, dynamic>?)?['display_name'] as String?,
    );
  }
}
