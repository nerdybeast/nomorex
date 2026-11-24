import '../utils/program_stats.dart';
import 'program.dart';

/// The PostgREST select every program-instance query uses: the program's name
/// and week/day structure plus each materialized workout's status, so an
/// instance can compute its progress (counts and check marks) without further
/// queries. One shared string so the lists and the detail fetch can't drift.
const kProgramInstanceSelect =
    '*, programs(name, program_weeks(id, position, week_number, '
    'program_days(id, position, is_rest_day, program_sessions(id, position)))), '
    'workouts(id, title, program_day_id, program_session_id, status)';

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
    this.workoutStatusByKey = const {},
    this.workoutIdByKey = const {},
    this.workoutTitleByKey = const {},
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

  /// Each materialized workout's key (`workoutKey`: its session, or its day
  /// when it has none) -> its status.
  final Map<String, String> workoutStatusByKey;

  /// Each materialized workout's key (as in [workoutStatusByKey]) -> its id.
  final Map<String, String> workoutIdByKey;

  /// Each materialized workout's key -> its title: the day's ("Day 3"), or
  /// "Day 1 · AM" on a split day (see `start_program`).
  final Map<String, String> workoutTitleByKey;

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
      workoutStatusByKey: workoutStatusByKey,
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

  /// Where the run stands today (see [runToday]), or null when [structure]
  /// wasn't loaded, the run hasn't started or its last week has passed.
  RunToday? get today {
    final weeks = structure;
    return weeks == null ? null : runToday(weeks, startedAt);
  }

  /// The workout to open for today: the first of today's sessions not yet
  /// finished, or the first one when all are. Null on a rest day, outside
  /// the run, or when today has no program day.
  String? get todaysWorkoutId {
    final day = today?.day;
    if (day == null || day.isRest) return null;
    final open = day.keys.where((k) => workoutStatusByKey[k] != 'finished');
    final key = open.isNotEmpty ? open.first : day.keys.first;
    return workoutIdByKey[key];
  }

  /// The title of [todaysWorkoutId]'s workout ("Day 3", "Day 1 · AM").
  String? get todaysWorkoutTitle {
    final id = todaysWorkoutId;
    if (id == null) return null;
    for (final e in workoutIdByKey.entries) {
      if (e.value == id) return workoutTitleByKey[e.key];
    }
    return null;
  }

  /// The run has started and its last week is behind it, but nobody has
  /// marked it complete: it's still active, with nothing left on the
  /// calendar.
  bool get scheduleFinished {
    final weeks = structure;
    if (weeks == null || !isActive) return false;
    final now = DateTime.now();
    final started = !DateTime(startedAt.year, startedAt.month, startedAt.day)
        .isAfter(DateTime(now.year, now.month, now.day));
    return started && runToday(weeks, startedAt) == null;
  }

  /// Days until the run's next training day after today (1 = tomorrow), or
  /// null when none is left or [structure] wasn't loaded.
  int? get daysToNextSession {
    final weeks = structure;
    return weeks == null ? null : daysUntilNextTraining(weeks, startedAt);
  }

  /// Whether every one of today's workouts is finished.
  bool get todaysWorkoutsDone {
    final day = today?.day;
    return day != null && !day.isRest && day.keys.every((k) => workoutStatusByKey[k] == 'finished');
  }

  /// Whether [day] earns a check mark (see [isDayChecked]).
  bool isDayCheckedFor(StatsDay day) =>
      isDayChecked(day, workoutStatusByKey: workoutStatusByKey, clock: _clock);

  /// Whether [week] earns a check mark (see [isWeekDone]).
  bool isWeekCheckedFor(StatsWeek week) =>
      isWeekDone(week, workoutStatusByKey: workoutStatusByKey, clock: _clock);

  factory ProgramInstance.fromJson(Map<String, dynamic> json) {
    final programMap = json['programs'] as Map<String, dynamic>?;
    final rawWeeks = programMap?['program_weeks'] == null
        ? null
        : sortedWeekJson(programMap!['program_weeks'] as List);
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
      structure: rawWeeks == null
          ? null
          : [
              for (var i = 0; i < rawWeeks.length; i++) StatsWeek.fromJson(rawWeeks[i], weekIndex: i),
            ],
      workoutStatusByKey: {
        for (final w in rawWorkouts ?? const [])
          ?workoutKey(w as Map<String, dynamic>): w['status'] as String,
      },
      workoutIdByKey: {
        for (final w in rawWorkouts ?? const [])
          ?workoutKey(w as Map<String, dynamic>): w['id'] as String,
      },
      workoutTitleByKey: {
        for (final w in rawWorkouts ?? const [])
          if ((w as Map<String, dynamic>)['title'] case final String title) ?workoutKey(w): title,
      },
    );
  }
}
