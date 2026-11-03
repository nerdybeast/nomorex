import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/personal_bests/utils/progression_axis.dart';

List<String> _labels(DateTime first, DateTime last) =>
    progressionXTicks(first, last).map((t) => t.label).toList();

void main() {
  group('progressionXTicks', () {
    test('a multi-year history ticks each new year', () {
      expect(
        _labels(DateTime(2022, 10, 19), DateTime(2026, 11, 2)),
        ['2023', '2024', '2025', '2026'],
      );
    });

    test('ticks sit on Jan 1 and stay inside the range', () {
      final first = DateTime(2022, 10, 19);
      final last = DateTime(2026, 11, 2);
      for (final tick in progressionXTicks(first, last)) {
        expect(tick.date.month, 1);
        expect(tick.date.day, 1);
        expect(tick.date.isBefore(first), isFalse);
        expect(tick.date.isAfter(last), isFalse);
      }
    });

    test('a long history thins to at most five year labels', () {
      final labels = _labels(DateTime(2010, 6, 1), DateTime(2026, 6, 1));
      expect(labels.length, lessThanOrEqualTo(5));
      expect(labels.first, '2011');
    });

    test('under a year ticks months, with January shown as the year', () {
      expect(
        _labels(DateTime(2025, 10, 15), DateTime(2026, 2, 20)),
        ['Nov', 'Dec', '2026', 'Feb'],
      );
    });

    test('within a single month labels the first and last day', () {
      expect(
        _labels(DateTime(2026, 3, 4), DateTime(2026, 3, 25)),
        ['Mar 4', 'Mar 25'],
      );
    });

    test('a single day gets one label', () {
      final day = DateTime(2026, 3, 4);
      expect(_labels(day, day), ['Mar 4']);
    });
  });

  group('formatAxisWeight', () {
    test('rounds pounds to whole numbers', () {
      expect(formatAxisWeight(75, 'lbs'), '165 lbs');
    });

    test('keeps kg to one trimmed decimal', () {
      expect(formatAxisWeight(52.5, 'kg'), '52.5 kg');
      expect(formatAxisWeight(60, 'kg'), '60 kg');
    });
  });
}
