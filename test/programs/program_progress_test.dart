import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/programs/utils/program_progress.dart';

void main() {
  group('isProgramUpcoming', () {
    test('true when started_at is after today', () {
      final future = DateTime.now().add(const Duration(days: 7));
      expect(isProgramUpcoming(future), isTrue);
    });

    test('false when started_at is today', () {
      expect(isProgramUpcoming(DateTime.now()), isFalse);
    });

    test('false when started_at is in the past', () {
      final past = DateTime.now().subtract(const Duration(days: 7));
      expect(isProgramUpcoming(past), isFalse);
    });
  });

  group('isProgramDayToday', () {
    test('true when the computed day date matches today', () {
      final today = DateTime.now();
      final startedAt = today.subtract(const Duration(days: 3));
      expect(isProgramDayToday(startedAt, 3), isTrue);
    });

    test('false when the computed day date is not today', () {
      final today = DateTime.now();
      final startedAt = today.subtract(const Duration(days: 3));
      expect(isProgramDayToday(startedAt, 0), isFalse);
      expect(isProgramDayToday(startedAt, 10), isFalse);
    });

    test('false for a future program (no day has happened yet)', () {
      final startedAt = DateTime.now().add(const Duration(days: 5));
      expect(isProgramDayToday(startedAt, 0), isFalse);
    });
  });
}
