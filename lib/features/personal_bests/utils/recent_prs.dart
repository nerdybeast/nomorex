import '../models/personal_best.dart';

/// Orders PR entries newest first by the date the PR was *achieved*, with the
/// save time breaking ties between entries on the same day.
///
/// This is the "current" ordering My PRs, PR history and the dashboard all
/// share. Ordering by save time alone made back-filled history (an old PR
/// entered today) masquerade as the lift's latest result.
int compareByRecency(PersonalBest a, PersonalBest b) {
  final byDate = b.date.compareTo(a.date);
  return byDate != 0 ? byDate : b.updatedAt.compareTo(a.updatedAt);
}

/// Each lift's current entry (newest by [compareByRecency]), with the lifts
/// themselves ordered by that entry, most recent first.
List<PersonalBest> latestPrPerExercise(List<PersonalBest> entries) {
  final latest = <String, PersonalBest>{};
  for (final pr in entries) {
    final current = latest[pr.exerciseId];
    if (current == null || compareByRecency(pr, current) < 0) {
      latest[pr.exerciseId] = pr;
    }
  }
  return latest.values.toList()..sort(compareByRecency);
}
