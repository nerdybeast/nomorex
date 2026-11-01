import '../utils/program_stats.dart';

/// The PostgREST select every program-instance query uses: the program's name
/// and week/day structure plus each materialized workout's status, so an
/// instance can compute its progress (counts and check marks) without further
/// queries. One shared string so the lists and the detail fetch can't drift.
const kProgramInstanceSelect =
    '*, programs(name, program_weeks(id, position, program_days(id, position, is_rest_day))), '
    'workouts(id, program_day_id, status)';

/// One user's "run" of a program, created when they hit Start. Owns the
/// batch of materialized workouts (`workouts.program_instance_id`).
class ProgramInstance {
  const ProgramInstance({
    required this.id,
    required this.programId,
    required this.userId,
    required this.startedAt,
    required this.status,
    this.programName,
    this.completedAt,
    this.structure,
    this.workoutStatusByDayId = const {},
  });

  final String id;
  final String programId;
  final String? programName;
  final String userId;
  final DateTime startedAt;
  final String status; // 'active' | 'completed' | 'abandoned'

  /// When the run was completed or abandoned; null while active.
  final DateTime? completedAt;

  /// The program's weeks and days, when the query embedded them. Null on
  /// queries that don't (e.g. the single-instance detail fetch).
  final List<StatsWeek>? structure;

  /// `program_day_id` -> status of the workout that day materialized into.
  final Map<String, String> workoutStatusByDayId;

  bool get isActive => status == 'active';

  /// Weeks / days / workouts done out of total, or null when [structure]
  /// wasn't loaded. Computed on read, not on parse, because "days passed"
  /// moves with the clock.
  ProgramStats? get stats {
    final weeks = structure;
    if (weeks == null) return null;
    final c = _clock;
    return runStats(
      weeks,
      workoutStatusByDayId: workoutStatusByDayId,
      startedAt: c.startedAt,
      asOf: c.asOf,
      ended: c.ended,
    );
  }

  RunClock get _clock {
    final end = completedAt;
    final ended = !isActive && end != null;
    return RunClock(
      startedAt: startedAt,
      asOf: ended ? end.toLocal() : DateTime.now(),
      ended: ended,
    );
  }

  /// Whether [day] earns a check mark (see [isDayChecked]).
  bool isDayCheckedFor(StatsDay day) =>
      isDayChecked(day, workoutStatusByDayId: workoutStatusByDayId, clock: _clock);

  /// Whether [week] earns a check mark (see [isWeekDone]).
  bool isWeekCheckedFor(StatsWeek week) =>
      isWeekDone(week, workoutStatusByDayId: workoutStatusByDayId, clock: _clock);

  factory ProgramInstance.fromJson(Map<String, dynamic> json) {
    final programMap = json['programs'] as Map<String, dynamic>?;
    final rawWeeks = programMap?['program_weeks'] as List?;
    final rawWorkouts = json['workouts'] as List?;
    return ProgramInstance(
      id: json['id'] as String,
      programId: json['program_id'] as String,
      programName: programMap?['name'] as String?,
      userId: json['user_id'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      status: json['status'] as String,
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
      structure: rawWeeks
          ?.map((e) => StatsWeek.fromJson(e as Map<String, dynamic>))
          .toList(),
      workoutStatusByDayId: {
        for (final w in rawWorkouts ?? const [])
          if ((w as Map<String, dynamic>)['program_day_id'] != null)
            w['program_day_id'] as String: w['status'] as String,
      },
    );
  }
}
