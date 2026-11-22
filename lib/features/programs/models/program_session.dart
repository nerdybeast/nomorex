import 'program_exercise.dart';

/// The most sessions a program day holds. The database enforces it
/// (`enforce_program_day_session_limit`, `day_full`).
const kMaxSessionsPerDay = 3;

/// One of a program day's 1–3 sessions (AM / PM, …). Each materializes into
/// its own workout on the day's date when the program is started.
class ProgramSession {
  const ProgramSession({
    required this.id,
    required this.programDayId,
    required this.position,
    this.title,
    this.notes,
    this.exercises = const [],
  });

  final String id;
  final String programDayId;

  /// Optional; [label] falls back to "Session N".
  final String? title;
  final String? notes;

  /// Order within the day.
  final int position;
  final List<ProgramExercise> exercises;

  /// The session's title, or "Session N" for the session at [index] (0-based)
  /// when it has none.
  String label(int index) {
    final t = title?.trim();
    return t == null || t.isEmpty ? 'Session ${index + 1}' : t;
  }

  factory ProgramSession.fromJson(Map<String, dynamic> json) {
    final exercises = ((json['program_exercises'] as List?) ?? const [])
        .map((e) => ProgramExercise.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    return ProgramSession(
      id: json['id'] as String,
      programDayId: json['program_day_id'] as String,
      title: json['title'] as String?,
      notes: json['notes'] as String?,
      position: json['position'] as int,
      exercises: exercises,
    );
  }
}
