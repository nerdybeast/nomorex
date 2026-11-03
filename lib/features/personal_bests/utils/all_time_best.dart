import '../../../core/utils/one_rep_max_formula.dart';
import '../models/personal_best.dart';

/// The entry with the highest estimated 1RM under [formula], or null when no
/// entry can be estimated.
///
/// Entries are compared by estimated 1RM rather than raw weight so a 5-rep
/// set can outrank a lighter single. Singles count as-is; entries outside
/// 1..[kMaxEstimableReps] reps can't be estimated and are skipped. On a tie
/// the earliest entry wins: the first time that level was reached.
///
/// Display only. `oneRepMaxProvider` still programs percentages from the
/// *latest* entry, not this one.
PersonalBest? allTimeBest(
  List<PersonalBest> entries,
  OneRepMaxFormula formula,
) {
  PersonalBest? best;
  double? bestScore;
  for (final pr in entries) {
    final score = estimateOneRepMaxKg(
      weightKg: pr.weightKg,
      reps: pr.reps,
      formula: formula,
    );
    if (score == null) continue;
    final beats = bestScore == null ||
        score > bestScore ||
        (score == bestScore && pr.date.isBefore(best!.date));
    if (beats) {
      best = pr;
      bestScore = score;
    }
  }
  return best;
}
