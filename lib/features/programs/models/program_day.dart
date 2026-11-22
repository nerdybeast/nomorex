import 'program_exercise.dart';
import 'program_session.dart';

/// One calendar day within a program week. Its exercises sit in 1–3
/// [sessions], each of which maps to its own `workouts` row, on this day's
/// date, once the program is started.
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
    this.sessions = const [],
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

  /// In order. Every day the app creates has at least one; a query that
  /// doesn't embed them (a list's shallow select) leaves this empty.
  final List<ProgramSession> sessions;

  /// Every exercise of the day, session by session, in order.
  List<ProgramExercise> get exercises => [for (final s in sessions) ...s.exercises];

  /// Whether the day is split into sessions, so screens show each one.
  bool get hasMultipleSessions => sessions.length > 1;

  /// Whether another session fits ([kMaxSessionsPerDay]).
  bool get canAddSession => sessions.length < kMaxSessionsPerDay;

  /// The ids each of the day's workouts is keyed by in a run: its sessions',
  /// or the day's own when no session was loaded (a run's workout with no
  /// session is keyed by its day; see `workoutKey`).
  List<String> get workoutKeys => sessions.isEmpty ? [id] : [for (final s in sessions) s.id];

  factory ProgramDay.fromJson(Map<String, dynamic> json, {int? dayOffset}) {
    final sessions = ((json['program_sessions'] as List?) ?? const [])
        .map((e) => ProgramSession.fromJson(e as Map<String, dynamic>))
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
      sessions: sessions,
    );
  }
}
