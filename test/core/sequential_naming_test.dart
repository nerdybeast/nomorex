import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/core/utils/sequential_naming.dart';

void main() {
  test('returns "Program 1" when there are no existing names', () {
    expect(nextSequentialName([], 'Program'), 'Program 1');
  });

  test('returns one past the highest matching number', () {
    expect(
      nextSequentialName(['Program 1', 'Program 2', 'Program 3'], 'Program'),
      'Program 4',
    );
  });

  test('ignores names that do not match the prefix pattern', () {
    expect(
      nextSequentialName(['Program 1', 'Leg Day Block', 'Program 5'], 'Program'),
      'Program 6',
    );
  });

  test('is not fooled by a gap left by a renamed or archived entry', () {
    // "Program 3" was renamed away, but "Program 5" still exists (e.g. archived),
    // so the next default must skip past it rather than reusing a lower number.
    expect(
      nextSequentialName(['Program 1', 'Program 2', 'Program 5'], 'Program'),
      'Program 6',
    );
  });

  test('matches case-insensitively', () {
    expect(nextSequentialName(['program 2'], 'Program'), 'Program 3');
  });

  test('trims whitespace before matching', () {
    expect(nextSequentialName(['  Program 2  '], 'Program'), 'Program 3');
  });

  test('works with a different prefix, e.g. Day', () {
    expect(nextSequentialName(['Day 1', 'Day 2'], 'Day'), 'Day 3');
  });
}
