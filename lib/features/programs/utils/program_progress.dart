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
