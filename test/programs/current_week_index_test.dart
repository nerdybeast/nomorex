import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/programs/utils/program_progress.dart';

void main() {
  // Two 3-day weeks: positions 0-2 and 3-5.
  const weeks = [
    [0, 1, 2],
    [3, 4, 5],
  ];
  final start = DateTime(2026, 11, 2);

  test('no run opens the first week', () {
    expect(currentWeekIndex(weeks, null), 0);
  });

  test('before the run starts opens the first week', () {
    expect(currentWeekIndex(weeks, start, now: DateTime(2026, 10, 30)), 0);
  });

  test('during the run opens the week holding today', () {
    expect(currentWeekIndex(weeks, start, now: DateTime(2026, 11, 3, 18)), 0);
    expect(currentWeekIndex(weeks, start, now: DateTime(2026, 11, 6)), 1);
  });

  test('after the last day opens the last week with days', () {
    expect(currentWeekIndex([...weeks, <int>[]], start, now: DateTime(2026, 12, 1)), 1);
  });
}
