import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/core/utils/duration_formatter.dart';

void main() {
  test('formats zero as 00:00:00', () {
    expect(formatDuration(Duration.zero), '00:00:00');
  });

  test('formats seconds and minutes under an hour', () {
    expect(formatDuration(const Duration(minutes: 5, seconds: 9)), '00:05:09');
  });

  test('formats hours, zero-padded', () {
    expect(formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)), '01:02:03');
  });

  test('formats durations over 99 hours without truncating the hour count', () {
    expect(formatDuration(const Duration(hours: 100, minutes: 0, seconds: 0)), '100:00:00');
  });

  test('clamps a negative duration to zero', () {
    expect(formatDuration(const Duration(seconds: -5)), '00:00:00');
  });
}
