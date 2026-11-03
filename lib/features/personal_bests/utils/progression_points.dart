import '../../../core/utils/one_rep_max_formula.dart';
import '../models/personal_best.dart';

/// One point on a lift's progression line.
typedef ProgressionPoint = ({DateTime date, double estimatedOneRepMaxKg});

/// How many plottable entries a lift needs before its trend line is drawn.
const kMinProgressionPoints = 3;

/// A lift's entries as estimated-1RM points, oldest first.
///
/// Scored the same way as `allTimeBest()` so a change in rep count doesn't
/// read as a jump or dip: singles plot as-is, multi-rep entries are estimated
/// with [formula], and entries outside 1..[kMaxEstimableReps] reps are dropped
/// (and so don't count toward [kMinProgressionPoints]).
List<ProgressionPoint> progressionPoints(
  List<PersonalBest> entries,
  OneRepMaxFormula formula,
) {
  final scored = <(PersonalBest, double)>[];
  for (final pr in entries) {
    final estimate = estimateOneRepMaxKg(
      weightKg: pr.weightKg,
      reps: pr.reps,
      formula: formula,
    );
    if (estimate != null) scored.add((pr, estimate));
  }
  scored.sort((a, b) {
    final byDate = a.$1.date.compareTo(b.$1.date);
    return byDate != 0 ? byDate : a.$1.updatedAt.compareTo(b.$1.updatedAt);
  });
  return [
    for (final (pr, estimate) in scored)
      (date: pr.date, estimatedOneRepMaxKg: estimate),
  ];
}
