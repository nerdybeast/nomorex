import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/core/utils/one_rep_max_formula.dart';
import 'package:nomorex/features/workouts/providers/one_rep_max_provider.dart';

OneRepMaxRow _row(
  String date,
  double weightKg,
  int reps, {
  String key = 'squat',
  String createdAt = '2026-01-01T00:00:00Z',
}) =>
    (
      key: key,
      weightKg: weightKg,
      reps: reps,
      date: DateTime.parse(date),
      createdAt: DateTime.parse(createdAt),
    );

void main() {
  const formula = OneRepMaxFormula.brzycki;

  test('a newer, lighter single replaces an older, heavier one', () {
    final maxes = foldOneRepMaxes([
      _row('2026-01-01', 100, 1),
      _row('2026-06-01', 90, 1),
    ], formula);

    expect(maxes['squat']!.kg, 90);
    expect(maxes['squat']!.isEstimated, isFalse);
  });

  test('a newer multi-rep entry replaces an older single, as an estimate', () {
    final maxes = foldOneRepMaxes([
      _row('2026-06-01', 95, 3),
      _row('2026-01-01', 100, 1),
    ], formula);

    expect(maxes['squat']!.isEstimated, isTrue);
    expect(
      maxes['squat']!.kg,
      closeTo(estimateOneRepMaxKg(weightKg: 95, reps: 3, formula: formula)!, 1e-9),
    );
  });

  test('on the same date, the later-created entry wins', () {
    final maxes = foldOneRepMaxes([
      _row('2026-06-01', 110, 1, createdAt: '2026-06-01T10:00:00Z'),
      _row('2026-06-01', 105, 1, createdAt: '2026-06-01T12:00:00Z'),
    ], formula);

    expect(maxes['squat']!.kg, 105);
  });

  test('a latest entry the formulas cannot use falls back to the previous one', () {
    final maxes = foldOneRepMaxes([
      _row('2026-01-01', 100, 1),
      _row('2026-06-01', 60, 15),
    ], formula);

    expect(maxes['squat']!.kg, 100);
    expect(maxes['squat']!.isEstimated, isFalse);
  });

  test('a key with only unusable entries is absent', () {
    final maxes = foldOneRepMaxes([_row('2026-06-01', 60, 15)], formula);

    expect(maxes.containsKey('squat'), isFalse);
  });

  test('each key keeps its own latest entry', () {
    final maxes = foldOneRepMaxes([
      _row('2026-06-01', 90, 1),
      _row('2026-01-01', 100, 1),
      _row('2026-01-01', 60, 1, key: 'bench'),
      _row('2026-07-01', 65, 1, key: 'bench'),
    ], formula);

    expect(maxes['squat']!.kg, 90);
    expect(maxes['bench']!.kg, 65);
  });

  group('oneRepMaxesByName', () {
    Map<String, dynamic> pr(String name, double kg, String date, {List<String> aliases = const []}) => {
          'weight_kg': kg,
          'reps': 1,
          'date': date,
          'created_at': '${date}T00:00:00Z',
          'exercises': {'name': name, 'aliases': aliases},
        };

    test('keys are normalized names, and an official exercise\'s aliases resolve too', () {
      final maxes = oneRepMaxesByName(
        [pr('  Clean   & Jerk', 120, '2026-01-01', aliases: ['C&J'])],
        OneRepMaxFormula.brzycki,
      );
      expect(maxes['clean & jerk']!.kg, 120);
      expect(maxes['c&j']!.kg, 120);
    });

    test('a name beats an alias for the same key', () {
      final maxes = oneRepMaxesByName(
        [
          // Newer, but only reaches "c&j" through an alias.
          pr('Clean & Jerk', 120, '2026-02-01', aliases: ['C&J']),
          // The user's own custom exercise literally named "C&J".
          pr('C&J', 100, '2026-01-01'),
        ],
        OneRepMaxFormula.brzycki,
      );
      expect(maxes['c&j']!.kg, 100);
      expect(maxes['clean & jerk']!.kg, 120);
    });
  });
}
