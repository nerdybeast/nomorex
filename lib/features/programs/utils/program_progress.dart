import 'program_day_date.dart';

bool _isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// True when a program's official start date hasn't arrived yet — the
/// instance exists but hasn't materially begun.
bool isProgramUpcoming(DateTime startedAt) {
  final today = DateTime.now();
  return _isSameDate(startedAt, today) ? false : startedAt.isAfter(today);
}

/// True when [position] (a program_day's global, 0-based order — see
/// [programDayDate]) lands on today, given the instance's [startedAt] date.
bool isProgramDayToday(DateTime startedAt, int position) =>
    _isSameDate(programDayDate(startedAt, position), DateTime.now());

/// Which week a program's screen opens on, as an index into the weeks.
///
/// [dayPositionsByWeek] holds each week's day positions (see
/// [programDayDate]). With no run ([startedAt] null), or before the run
/// starts, it's the first week. During the run it's the week holding today;
/// after the last day, the last week with days.
int currentWeekIndex(List<List<int>> dayPositionsByWeek, DateTime? startedAt, {DateTime? now}) {
  if (startedAt == null || dayPositionsByWeek.isEmpty) return 0;
  final today = now ?? DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  var lastWithDays = 0;
  for (var i = 0; i < dayPositionsByWeek.length; i++) {
    final positions = dayPositionsByWeek[i];
    if (positions.isEmpty) continue;
    lastWithDays = i;
    for (final p in positions) {
      if (_isSameDate(programDayDate(startedAt, p), today)) return i;
    }
  }
  final start = DateTime(startedAt.year, startedAt.month, startedAt.day);
  return todayDate.isAfter(start) ? lastWithDays : 0;
}
