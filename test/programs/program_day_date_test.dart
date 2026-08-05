import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/programs/utils/program_day_date.dart';

void main() {
  test('programDayDate adds position days to the start date', () {
    final start = DateTime(2026, 8, 4);
    expect(programDayDate(start, 0), DateTime(2026, 8, 4));
    expect(programDayDate(start, 1), DateTime(2026, 8, 5));
    expect(programDayDate(start, 6), DateTime(2026, 8, 10));
  });
}
