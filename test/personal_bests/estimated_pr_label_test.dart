import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/core/utils/one_rep_max_formula.dart';
import 'package:nomorex/features/personal_bests/models/personal_best.dart';
import 'package:nomorex/features/personal_bests/utils/estimated_pr_label.dart';

PersonalBest _pr({required double weightKg, required int reps}) => PersonalBest(
      id: '1',
      userId: 'u1',
      exerciseId: 'e1',
      exerciseName: 'Back Squat',
      weightKg: weightKg,
      reps: reps,
      date: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  test('labels a multi-rep PR with its estimated 1RM', () {
    expect(
      estimatedOneRepMaxLabel(
        _pr(weightKg: 100, reps: 5),
        OneRepMaxFormula.brzycki,
        'kg',
      ),
      'Est. 1RM 112.5 kg',
    );
  });

  test('is null on a single, where the estimate is just the lifted weight', () {
    expect(
      estimatedOneRepMaxLabel(
        _pr(weightKg: 165, reps: 1),
        OneRepMaxFormula.brzycki,
        'kg',
      ),
      isNull,
    );
  });

  test('is null past the usable rep range', () {
    expect(
      estimatedOneRepMaxLabel(
        _pr(weightKg: 60, reps: kMaxEstimableReps + 1),
        OneRepMaxFormula.brzycki,
        'kg',
      ),
      isNull,
    );
  });

  test('follows the chosen formula', () {
    expect(
      estimatedOneRepMaxLabel(
        _pr(weightKg: 100, reps: 5),
        OneRepMaxFormula.epley,
        'kg',
      ),
      'Est. 1RM 116.7 kg',
    );
  });

  test('renders both units when that is the preference', () {
    expect(
      estimatedOneRepMaxLabel(
        _pr(weightKg: 100, reps: 5),
        OneRepMaxFormula.brzycki,
        'both',
      ),
      'Est. 1RM 248 lbs / 113 kg',
    );
  });
}
