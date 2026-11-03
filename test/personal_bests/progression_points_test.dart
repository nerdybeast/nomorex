import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/core/utils/one_rep_max_formula.dart';
import 'package:nomorex/features/personal_bests/models/personal_best.dart';
import 'package:nomorex/features/personal_bests/utils/progression_points.dart';

PersonalBest _pr(double weightKg, int reps, DateTime date) => PersonalBest(
      id: '$weightKg-$reps-$date',
      userId: 'u1',
      exerciseId: 'e1',
      exerciseName: 'Back Squat',
      weightKg: weightKg,
      reps: reps,
      date: date,
      updatedAt: date,
    );

void main() {
  test('sorts oldest first', () {
    final points = progressionPoints([
      _pr(110, 1, DateTime(2026, 3, 1)),
      _pr(100, 1, DateTime(2026, 1, 1)),
      _pr(105, 1, DateTime(2026, 2, 1)),
    ], OneRepMaxFormula.brzycki);

    expect(points.map((p) => p.estimatedOneRepMaxKg), [100, 105, 110]);
    expect(points.first.date, DateTime(2026, 1, 1));
  });

  test('drops entries that cannot be estimated', () {
    final points = progressionPoints([
      _pr(100, 1, DateTime(2026, 1, 1)),
      _pr(60, 15, DateTime(2026, 2, 1)),
    ], OneRepMaxFormula.brzycki);

    expect(points, hasLength(1));
  });

  test('scores multi-rep entries with the given formula', () {
    final entries = [_pr(100, 10, DateTime(2026, 1, 1))];
    final brzycki = progressionPoints(entries, OneRepMaxFormula.brzycki);
    final lander = progressionPoints(entries, OneRepMaxFormula.lander);

    expect(brzycki.single.estimatedOneRepMaxKg, closeTo(133.4, 0.1));
    expect(lander.single.estimatedOneRepMaxKg, closeTo(134.1, 0.1));
  });
}
