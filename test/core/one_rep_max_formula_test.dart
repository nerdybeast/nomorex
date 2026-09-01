import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/core/utils/one_rep_max_formula.dart';

void main() {
  group('estimateOneRepMaxKg', () {
    // 100 kg x 5 is the reference case: the three formulas are meant to
    // disagree, and by roughly this much. If one of these drifts, a constant
    // was mistyped.
    test('Brzycki estimates 100kg x 5 at ~112.5kg', () {
      final est = estimateOneRepMaxKg(
        weightKg: 100,
        reps: 5,
        formula: OneRepMaxFormula.brzycki,
      );
      expect(est, closeTo(112.5, 0.1));
    });

    test('Epley estimates 100kg x 5 at ~116.7kg', () {
      final est = estimateOneRepMaxKg(
        weightKg: 100,
        reps: 5,
        formula: OneRepMaxFormula.epley,
      );
      expect(est, closeTo(116.7, 0.1));
    });

    test('Lander estimates 100kg x 5 at ~113.7kg', () {
      final est = estimateOneRepMaxKg(
        weightKg: 100,
        reps: 5,
        formula: OneRepMaxFormula.lander,
      );
      expect(est, closeTo(113.7, 0.1));
    });

    test('every formula returns the lifted weight itself at 1 rep', () {
      for (final formula in OneRepMaxFormula.values) {
        expect(
          estimateOneRepMaxKg(weightKg: 142.5, reps: 1, formula: formula),
          142.5,
          reason: 'formula: $formula',
        );
      }
    });

    test('returns null past the usable rep range', () {
      for (final formula in OneRepMaxFormula.values) {
        expect(
          estimateOneRepMaxKg(
            weightKg: 100,
            reps: kMaxEstimableReps + 1,
            formula: formula,
          ),
          isNull,
          reason: 'formula: $formula',
        );
      }
    });

    test('returns a value at the top of the usable rep range', () {
      expect(
        estimateOneRepMaxKg(
          weightKg: 100,
          reps: kMaxEstimableReps,
          formula: OneRepMaxFormula.brzycki,
        ),
        isNotNull,
      );
    });

    test('returns null below 1 rep', () {
      expect(
        estimateOneRepMaxKg(
          weightKg: 100,
          reps: 0,
          formula: OneRepMaxFormula.brzycki,
        ),
        isNull,
      );
    });

    test('scales linearly in weight, so it works in any unit', () {
      final kg = estimateOneRepMaxKg(
        weightKg: 100,
        reps: 4,
        formula: OneRepMaxFormula.brzycki,
      )!;
      final doubled = estimateOneRepMaxKg(
        weightKg: 200,
        reps: 4,
        formula: OneRepMaxFormula.brzycki,
      )!;
      expect(doubled, closeTo(kg * 2, 0.0001));
    });
  });

  group('oneRepMaxFormulaFromDb', () {
    test('round-trips every formula through its stored value', () {
      for (final formula in OneRepMaxFormula.values) {
        expect(oneRepMaxFormulaFromDb(oneRepMaxFormulaToDb(formula)), formula);
      }
    });

    test('falls back to Brzycki for null or an unknown value', () {
      expect(oneRepMaxFormulaFromDb(null), OneRepMaxFormula.brzycki);
      expect(oneRepMaxFormulaFromDb('wathan'), OneRepMaxFormula.brzycki);
    });
  });
}
