import 'program_day_date.dart';

bool _isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// True when a program's official start date hasn't arrived yet — the
/// instance exists but hasn't materially begun.
bool isProgramUpcoming(DateTime startedAt) {
  final today = DateTime.now();
  return _isSameDate(startedAt, today) ? false : startedAt.isAfter(today);
}

/// True when the day at [dayOffset] (`ProgramDay.dayOffset`, see
/// [programDayDate]) lands on today, given the instance's [startedAt] date.
bool isProgramDayToday(DateTime startedAt, int dayOffset) =>
    _isSameDate(programDayDate(startedAt, dayOffset), DateTime.now());

/// Which week a program's screen opens on, as an index into the weeks.
///
/// [dayOffsetsByWeek] holds each week's day offsets (`ProgramDay.dayOffset`,
/// see [programDayDate]). With no run ([startedAt] null), or before the run
/// starts, it's the first week. During the run it's the week holding today;
/// after the last day, the last week with days.
int currentWeekIndex(List<List<int>> dayOffsetsByWeek, DateTime? startedAt, {DateTime? now}) {
  if (startedAt == null || dayOffsetsByWeek.isEmpty) return 0;
  final today = now ?? DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  var lastWithDays = 0;
  for (var i = 0; i < dayOffsetsByWeek.length; i++) {
    final offsets = dayOffsetsByWeek[i];
    if (offsets.isEmpty) continue;
    lastWithDays = i;
    for (final p in offsets) {
      if (_isSameDate(programDayDate(startedAt, p), today)) return i;
    }
  }
  final start = DateTime(startedAt.year, startedAt.month, startedAt.day);
  return todayDate.isAfter(start) ? lastWithDays : 0;
}
