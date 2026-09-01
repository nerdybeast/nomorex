import '../../../core/utils/one_rep_max_formula.dart';
import '../../../core/utils/weight_converter.dart';
import '../models/personal_best.dart';

/// The "Est. 1RM ..." line shown beneath a PR, or null when there's nothing
/// worth showing.
///
/// Returns null for a single — every formula returns the lifted weight itself
/// at 1 rep, so the line would just repeat the number above it — and for rep
/// counts outside [kMaxEstimableReps], where the formulas stop meaning
/// anything.
String? estimatedOneRepMaxLabel(
  PersonalBest pr,
  OneRepMaxFormula formula,
  String unitPreference,
) {
  if (pr.reps <= 1) return null;
  final estimate = estimateOneRepMaxKg(
    weightKg: pr.weightKg,
    reps: pr.reps,
    formula: formula,
  );
  if (estimate == null) return null;
  return 'Est. 1RM ${formatWeightForPreference(estimate, unitPreference)}';
}
