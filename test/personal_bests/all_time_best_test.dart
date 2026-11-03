import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/core/utils/one_rep_max_formula.dart';
import 'package:nomorex/features/personal_bests/models/personal_best.dart';
import 'package:nomorex/features/personal_bests/utils/all_time_best.dart';

PersonalBest _pr(String id, double weightKg, int reps, DateTime date) =>
    PersonalBest(
      id: id,
      userId: 'u1',
      exerciseId: 'e1',
      exerciseName: 'Back Squat',
      weightKg: weightKg,
      reps: reps,
      date: date,
      updatedAt: date,
    );

void main() {
  const brzycki = OneRepMaxFormula.brzycki;

  test('a heavier single beats a lighter multi-rep entry', () {
    final single = _pr('single', 120, 1, DateTime(2026, 2, 1));
    final triple = _pr('triple', 100, 3, DateTime(2026, 1, 1)); // ~106 kg
    expect(allTimeBest([single, triple], brzycki)?.id, 'single');
  });

  test('a strong multi-rep entry beats a lighter single', () {
    final five = _pr('five', 115, 5, DateTime(2026, 1, 1)); // ~129 kg
    final single = _pr('single', 120, 1, DateTime(2026, 2, 1));
    expect(allTimeBest([single, five], brzycki)?.id, 'five');
  });

  test('a tie goes to the earliest entry', () {
    final later = _pr('later', 100, 1, DateTime(2026, 3, 1));
    final earlier = _pr('earlier', 100, 1, DateTime(2026, 1, 1));
    expect(allTimeBest([later, earlier], brzycki)?.id, 'earlier');
  });

  test('entries past the estimable rep range are skipped', () {
    final highReps = _pr('high', 200, 12, DateTime(2026, 2, 1));
    final single = _pr('single', 100, 1, DateTime(2026, 1, 1));
    expect(allTimeBest([highReps, single], brzycki)?.id, 'single');
  });

  test('returns null when nothing can be estimated', () {
    expect(allTimeBest(const [], brzycki), isNull);
    expect(
      allTimeBest([_pr('high', 200, 12, DateTime(2026, 1, 1))], brzycki),
      isNull,
    );
  });

  test('follows the formula', () {
    // Brzycki: 100x10 -> ~133.3, 125x3 -> ~132.4  => the ten wins.
    // Epley:   100x10 -> ~133.3, 125x3 -> 137.5   => the triple wins.
    final ten = _pr('ten', 100, 10, DateTime(2026, 1, 1));
    final triple = _pr('triple', 125, 3, DateTime(2026, 2, 1));
    expect(allTimeBest([ten, triple], OneRepMaxFormula.brzycki)?.id, 'ten');
    expect(allTimeBest([ten, triple], OneRepMaxFormula.epley)?.id, 'triple');
  });
}
