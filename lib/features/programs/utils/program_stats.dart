import '../models/program_day.dart';
import '../models/program_week.dart';

/// One scheduled day of a program, reduced to what the counts need.
class StatsDay {
  const StatsDay({required this.id, required this.dayOffset, required this.isRest, List<String>? workoutKeys})
      : workoutKeys = workoutKeys ?? const [];

  final String id;

  /// What each of the day's workouts is keyed by in a run's status map: its
  /// sessions' ids (`ProgramDay.workoutKeys`). Empty means one workout keyed
  /// by the day ([keys]).
  final List<String> workoutKeys;

  /// [workoutKeys], or the day's own id when it has none.
  List<String> get keys => workoutKeys.isEmpty ? [id] : workoutKeys;

  /// One workout per session.
  int get workoutCount => keys.length;

  /// Days from the run's start date to this day's date
  /// (`ProgramDay.dayOffset`: 7 × week index + place in the week).
  final int dayOffset;
  final bool isRest;

  factory StatsDay.fromDay(ProgramDay day) =>
      StatsDay(id: day.id, dayOffset: day.dayOffset, isRest: day.isRestDay, workoutKeys: day.workoutKeys);

  factory StatsDay.fromJson(Map<String, dynamic> json, {required int dayOffset}) {
    final sessions = ((json['program_sessions'] as List?) ?? const []).cast<Map<String, dynamic>>().toList()
      ..sort((a, b) => (a['position'] as int).compareTo(b['position'] as int));
    return StatsDay(
      id: json['id'] as String,
      dayOffset: dayOffset,
      isRest: (json['is_rest_day'] as bool?) ?? false,
      workoutKeys: [for (final s in sessions) s['id'] as String],
    );
  }
}

/// One week of a program, reduced to what the counts need.
class StatsWeek {
  const StatsWeek(this.days);

  final List<StatsDay> days;

  factory StatsWeek.fromWeek(ProgramWeek week) =>
      StatsWeek(week.days.map(StatsDay.fromDay).toList());

  /// [weekIndex] is the week's 0-based place in the program; see
  /// `ProgramWeek.fromJson`.
  factory StatsWeek.fromJson(Map<String, dynamic> json, {required int weekIndex}) {
    final raw = ((json['program_days'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .toList()
      ..sort((a, b) => (a['position'] as int).compareTo(b['position'] as int));
    return StatsWeek([
      for (var i = 0; i < raw.length; i++)
        StatsDay.fromJson(raw[i], dayOffset: weekIndex * kMaxDaysPerWeek + i),
    ]);
  }
}

/// Weeks / days / workouts of a program, and — for a run — how many of each
/// are done.
///
/// - **days** are every scheduled day, rest days included.
/// - **workouts** are the training days' sessions: each session of a non-rest
///   day materializes one workout when a program is started.
/// - A day is **completed** once its calendar date has passed.
/// - A workout is **completed** once it is `finished`.
/// - A day's check mark needs every one of its sessions finished.
/// - A week is **completed** once all its training workouts are finished (rest
///   days can't block it); a week with no training days completes when its
///   last day's date has passed.
class ProgramStats {
  const ProgramStats({
    required this.weeks,
    required this.days,
    required this.workouts,
    this.completedWeeks,
    this.completedDays,
    this.completedWorkouts,
  });

  final int weeks;
  final int days;
  final int workouts;

  /// Null for a template that hasn't been started.
  final int? completedWeeks;
  final int? completedDays;
  final int? completedWorkouts;

  bool get isRun => completedWeeks != null;
}

/// Totals for a program that isn't running.
ProgramStats templateStats(List<StatsWeek> weeks) {
  final days = weeks.expand((w) => w.days);
  return ProgramStats(
    weeks: weeks.length,
    days: days.length,
    workouts: days.where((d) => !d.isRest).fold<int>(0, (n, d) => n + d.workoutCount),
  );
}

/// The clock a run's progress is measured against: [asOf] is "now" for an
/// active run; for an ended run it is the end time with [ended] true so the
/// day it ended on still counts.
class RunClock {
  const RunClock({required this.startedAt, required this.asOf, this.ended = false});

  final DateTime startedAt;
  final DateTime asOf;
  final bool ended;

  /// Days before this date have passed. Built from y/m/d (not Duration math)
  /// so a DST change can't shift a day.
  DateTime get _cutoff => DateTime(asOf.year, asOf.month, asOf.day + (ended ? 1 : 0));

  bool hasPassed(StatsDay d) =>
      DateTime(startedAt.year, startedAt.month, startedAt.day + d.dayOffset)
          .isBefore(_cutoff);
}

/// Every one of the day's workouts (one per session) is finished.
bool _finished(StatsDay d, Map<String, String> status) => d.keys.every((k) => status[k] == 'finished');

/// A day's check mark: a training day is checked once its workout is
/// finished; a rest day (no workout) once its date has passed. Deliberately
/// not the same rule as [ProgramStats.completedDays], which counts calendar
/// days regardless of what was logged.
bool isDayChecked(
  StatsDay day, {
  required Map<String, String> workoutStatusByKey,
  required RunClock clock,
}) =>
    day.isRest ? clock.hasPassed(day) : _finished(day, workoutStatusByKey);

/// A week is done once all its training workouts are finished (rest days
/// can't block it); a week with no training days is done once its last day's
/// date has passed. An empty week is never done.
bool isWeekDone(
  StatsWeek week, {
  required Map<String, String> workoutStatusByKey,
  required RunClock clock,
}) {
  if (week.days.isEmpty) return false;
  final training = week.days.where((d) => !d.isRest);
  return training.isEmpty
      ? week.days.every(clock.hasPassed)
      : training.every((d) => _finished(d, workoutStatusByKey));
}

/// Totals plus progress for a run started on [startedAt].
///
/// [workoutStatusByKey] maps each materialized workout's key (`workoutKey`:
/// its session, or its day when it has none) to its status; see [RunClock]
/// for [asOf] / [ended].
ProgramStats runStats(
  List<StatsWeek> weeks, {
  required Map<String, String> workoutStatusByKey,
  required DateTime startedAt,
  required DateTime asOf,
  bool ended = false,
}) {
  final clock = RunClock(startedAt: startedAt, asOf: asOf, ended: ended);
  final allDays = weeks.expand((w) => w.days).toList();

  return ProgramStats(
    weeks: weeks.length,
    days: allDays.length,
    workouts: allDays.where((d) => !d.isRest).fold<int>(0, (n, d) => n + d.workoutCount),
    completedWeeks: weeks
        .where((w) => isWeekDone(w, workoutStatusByKey: workoutStatusByKey, clock: clock))
        .length,
    completedDays: allDays.where(clock.hasPassed).length,
    completedWorkouts: allDays
        .where((d) => !d.isRest)
        .fold<int>(0, (n, d) => n + d.keys.where((k) => workoutStatusByKey[k] == 'finished').length),
  );
}

/// The key a run's workout is stored under in a status or id map: its
/// `program_session_id`, or its `program_day_id` for a workout with no session
/// (materialized from a day that had none). Matches [StatsDay.keys] and
/// `ProgramDay.workoutKeys`.
String? workoutKey(Map<String, dynamic> workoutRow) =>
    (workoutRow['program_session_id'] ?? workoutRow['program_day_id']) as String?;

/// Where a run stands on one date: the week it's in and, when that date is
/// one of the program's days, the day.
class RunToday {
  const RunToday({required this.weekIndex, required this.weekCount, this.day, this.dayInWeek});

  /// 0-based.
  final int weekIndex;
  final int weekCount;

  /// The program day dated today; null on a date the week has no day for
  /// (a short or empty week).
  final StatsDay? day;

  /// [day]'s place in its week, 1-based ("Day 3"); null with [day].
  final int? dayInWeek;
}

/// Where a run started on [startedAt] stands on [now] (default today), or
/// null before it starts and after its last week. Days are matched by
/// `dayOffset`, the same date math as `programDayDate`.
RunToday? runToday(List<StatsWeek> weeks, DateTime startedAt, {DateTime? now}) {
  final today = now ?? DateTime.now();
  // UTC dates so a DST change can't make a day 23 or 25 hours long.
  final offset = DateTime.utc(today.year, today.month, today.day)
      .difference(DateTime.utc(startedAt.year, startedAt.month, startedAt.day))
      .inDays;
  if (offset < 0) return null;
  final weekIndex = offset ~/ kMaxDaysPerWeek;
  if (weekIndex >= weeks.length) return null;
  final days = weeks[weekIndex].days;
  for (var i = 0; i < days.length; i++) {
    if (days[i].dayOffset == offset) {
      return RunToday(weekIndex: weekIndex, weekCount: weeks.length, day: days[i], dayInWeek: i + 1);
    }
  }
  return RunToday(weekIndex: weekIndex, weekCount: weeks.length);
}

/// How many days a week a program trains, for a row with no description:
/// "5 days/wk", or "4–6 days/wk" when its weeks differ. Counts the weeks that
/// have any training day, so a deload or empty week doesn't drag it down to
/// zero. Null when the program has no training days yet.
String? daysPerWeekLabel(List<StatsWeek> weeks) {
  final counts = [
    for (final w in weeks)
      if (w.days.where((d) => !d.isRest).length case final n when n > 0) n,
  ];
  if (counts.isEmpty) return null;
  final low = counts.reduce((a, b) => a < b ? a : b);
  final high = counts.reduce((a, b) => a > b ? a : b);
  if (low == high) return '$low ${low == 1 ? 'day' : 'days'}/wk';
  return '$low–$high days/wk';
}

/// Days from [now] (default today) to the next training day of a run
/// started on [startedAt] (1 = tomorrow), or null when none is left. For a
/// rest day's "next session tomorrow".
int? daysUntilNextTraining(List<StatsWeek> weeks, DateTime startedAt, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final offset = DateTime.utc(today.year, today.month, today.day)
      .difference(DateTime.utc(startedAt.year, startedAt.month, startedAt.day))
      .inDays;
  int? next;
  for (final w in weeks) {
    for (final d in w.days) {
      if (!d.isRest && d.dayOffset > offset && (next == null || d.dayOffset < next)) next = d.dayOffset;
    }
  }
  return next == null ? null : next - offset;
}
