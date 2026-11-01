import '../models/program_day.dart';
import '../models/program_week.dart';

/// One scheduled day of a program, reduced to what the counts need.
class StatsDay {
  const StatsDay({required this.id, required this.position, required this.isRest});

  final String id;

  /// Global, 0-based order across the whole program (`program_days.position`);
  /// the day's date is the run's start date plus this many days.
  final int position;
  final bool isRest;

  factory StatsDay.fromDay(ProgramDay day) =>
      StatsDay(id: day.id, position: day.position, isRest: day.isRestDay);

  factory StatsDay.fromJson(Map<String, dynamic> json) => StatsDay(
        id: json['id'] as String,
        position: json['position'] as int,
        isRest: (json['is_rest_day'] as bool?) ?? false,
      );
}

/// One week of a program, reduced to what the counts need.
class StatsWeek {
  const StatsWeek(this.days);

  final List<StatsDay> days;

  factory StatsWeek.fromWeek(ProgramWeek week) =>
      StatsWeek(week.days.map(StatsDay.fromDay).toList());

  factory StatsWeek.fromJson(Map<String, dynamic> json) {
    final raw = (json['program_days'] as List?) ?? const [];
    return StatsWeek(
      raw.map((e) => StatsDay.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

/// Weeks / days / workouts of a program, and — for a run — how many of each
/// are done.
///
/// - **days** are every scheduled day, rest days included.
/// - **workouts** are the training days only: each non-rest day materializes
///   exactly one workout when a program is started.
/// - A day is **completed** once its calendar date has passed.
/// - A workout is **completed** once it is `finished`.
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
    workouts: days.where((d) => !d.isRest).length,
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
      DateTime(startedAt.year, startedAt.month, startedAt.day + d.position)
          .isBefore(_cutoff);
}

bool _finished(StatsDay d, Map<String, String> status) => status[d.id] == 'finished';

/// A day's check mark: a training day is checked once its workout is
/// finished; a rest day (no workout) once its date has passed. Deliberately
/// not the same rule as [ProgramStats.completedDays], which counts calendar
/// days regardless of what was logged.
bool isDayChecked(
  StatsDay day, {
  required Map<String, String> workoutStatusByDayId,
  required RunClock clock,
}) =>
    day.isRest ? clock.hasPassed(day) : _finished(day, workoutStatusByDayId);

/// A week is done once all its training workouts are finished (rest days
/// can't block it); a week with no training days is done once its last day's
/// date has passed. An empty week is never done.
bool isWeekDone(
  StatsWeek week, {
  required Map<String, String> workoutStatusByDayId,
  required RunClock clock,
}) {
  if (week.days.isEmpty) return false;
  final training = week.days.where((d) => !d.isRest);
  return training.isEmpty
      ? week.days.every(clock.hasPassed)
      : training.every((d) => _finished(d, workoutStatusByDayId));
}

/// Totals plus progress for a run started on [startedAt].
///
/// [workoutStatusByDayId] maps `program_day_id` to the materialized workout's
/// status; see [RunClock] for [asOf] / [ended].
ProgramStats runStats(
  List<StatsWeek> weeks, {
  required Map<String, String> workoutStatusByDayId,
  required DateTime startedAt,
  required DateTime asOf,
  bool ended = false,
}) {
  final clock = RunClock(startedAt: startedAt, asOf: asOf, ended: ended);
  final allDays = weeks.expand((w) => w.days).toList();

  return ProgramStats(
    weeks: weeks.length,
    days: allDays.length,
    workouts: allDays.where((d) => !d.isRest).length,
    completedWeeks: weeks
        .where((w) => isWeekDone(w, workoutStatusByDayId: workoutStatusByDayId, clock: clock))
        .length,
    completedDays: allDays.where(clock.hasPassed).length,
    completedWorkouts:
        allDays.where((d) => !d.isRest && _finished(d, workoutStatusByDayId)).length,
  );
}
