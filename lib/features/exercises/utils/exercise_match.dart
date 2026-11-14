import '../../../core/utils/exercise_name.dart';
import '../models/exercise.dart';

/// The exercise in [catalog] that [name] refers to, or null.
///
/// The same order as the server's `find_exercise_for_user()`: an active
/// official exercise whose name or alias matches, then a retired official one,
/// then the oldest custom exercise with that name. Keep them in step, or the
/// app and the server pick different rows for one name.
Exercise? findExerciseByName(Iterable<Exercise> catalog, String name) {
  final key = normalizeExerciseName(name);
  if (key.isEmpty) return null;
  Exercise? best;
  for (final e in catalog) {
    if (!e.matchKeys.contains(key)) continue;
    if (best == null || _rank(e).compareTo(_rank(best)) < 0) best = e;
  }
  return best;
}

(int, int, DateTime) _rank(Exercise e) =>
    (e.isPredefined ? 0 : 1, e.isRetired ? 1 : 0, e.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0));

extension on (int, int, DateTime) {
  int compareTo((int, int, DateTime) other) {
    final a = $1.compareTo(other.$1);
    if (a != 0) return a;
    final b = $2.compareTo(other.$2);
    if (b != 0) return b;
    return $3.compareTo(other.$3);
  }
}

/// Whether [e] should show for a picker search of [query]: its name or any
/// alias contains it.
bool exerciseMatchesQuery(Exercise e, String query) {
  final q = normalizeExerciseName(query);
  return q.isEmpty || e.matchKeys.any((k) => k.contains(q));
}
