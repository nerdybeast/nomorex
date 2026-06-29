import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/workouts/utils/set_builder_parser.dart';

void main() {
  test('single percentage applies to every set', () {
    final sets = parseSetBuilder('3 x 5 @ 80');
    expect(sets.length, 3);
    expect(sets.every((s) => s.targetReps == 5), isTrue);
    expect(sets.map((s) => s.percentage), [80, 80, 80]);
  });

  test('hyphenated list maps one percentage per set', () {
    final sets = parseSetBuilder('4 x 2 @ 65-68-71-68');
    expect(sets.map((s) => s.percentage), [65, 68, 71, 68]);
    expect(sets.every((s) => s.targetReps == 2), isTrue);
  });

  test('is case-insensitive and tolerates extra spaces', () {
    final sets = parseSetBuilder('  2 X 3  @  70 - 75 ');
    expect(sets.map((s) => s.percentage), [70, 75]);
  });

  test('percentage-list length mismatch throws', () {
    expect(() => parseSetBuilder('4 x 2 @ 65-68'), throwsFormatException);
  });

  test('missing @ section throws', () {
    expect(() => parseSetBuilder('4 x 2'), throwsFormatException);
  });

  test('non-numeric values throw', () {
    expect(() => parseSetBuilder('a x 2 @ 80'), throwsFormatException);
    expect(() => parseSetBuilder('4 x 2 @ heavy'), throwsFormatException);
  });
}
