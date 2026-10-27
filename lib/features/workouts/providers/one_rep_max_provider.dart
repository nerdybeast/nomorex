import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../../../core/utils/one_rep_max_formula.dart';
import '../../../shared/models/one_rep_max.dart';

part 'one_rep_max_provider.g.dart';

/// One `personal_bests` row, reduced to what [foldOneRepMaxes] needs.
typedef OneRepMaxRow = ({
  String key,
  double weightKg,
  int reps,
  DateTime date,
  DateTime createdAt,
});

/// Folds `personal_bests` rows into one [OneRepMax] per key.
///
/// The user's *latest* PR entry is their current 1RM, whatever its rep count —
/// the same entry the My PRs card shows as current. A newer, lighter PR has to
/// replace an older, heavier one, or a lifter coming back from a layoff keeps
/// getting programmed off a number they can no longer hit. "Latest" is by
/// `date`, with `created_at` breaking ties so a second entry on the same day
/// acts as the correction. A single is used as-is; a multi-rep entry is
/// estimated with [formula]. Rows outside the formulas' usable rep range are
/// skipped, so the next most recent usable entry wins, and a key with only
/// 20-rep PRs is absent from the map — the same "no 1RM" state as having no
/// PRs at all.
@visibleForTesting
Map<String, OneRepMax> foldOneRepMaxes(
  Iterable<OneRepMaxRow> rows,
  OneRepMaxFormula formula,
) {
  final sorted = rows.toList()
    ..sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
    });

  final result = <String, OneRepMax>{};
  for (final row in sorted) {
    if (result.containsKey(row.key)) continue;
    if (row.reps == 1) {
      result[row.key] = OneRepMax.measured(row.weightKg);
      continue;
    }
    final est = estimateOneRepMaxKg(
      weightKg: row.weightKg,
      reps: row.reps,
      formula: formula,
    );
    if (est != null) result[row.key] = OneRepMax.estimated(est);
  }
  return result;
}

/// exerciseId -> the user's current 1RM (kg) for that lift: their latest PR
/// entry, estimated when it isn't a single. See [foldOneRepMaxes].
@Riverpod(keepAlive: true)
Future<Map<String, OneRepMax>> oneRepMax(Ref ref) async {
  ref.watch(authStateProvider);
  // Watched, not read: switching formulas in settings has to recompute every
  // estimate on screen.
  final formula = ref.watch(oneRepMaxFormulaProvider);
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return {};

  final data = await Supabase.instance.client
      .from('personal_bests')
      .select('exercise_id, weight_kg, reps, date, created_at')
      .eq('user_id', userId);

  return foldOneRepMaxes(
    [
      for (final row in data as List)
        (
          key: row['exercise_id'] as String,
          weightKg: (row['weight_kg'] as num).toDouble(),
          reps: (row['reps'] as num).toInt(),
          date: DateTime.parse(row['date'] as String),
          createdAt: DateTime.parse(row['created_at'] as String),
        ),
    ],
    formula,
  );
}

/// Lowercased exercise name -> the user's current 1RM (kg), by the same
/// latest-entry rule as [oneRepMax].
///
/// [oneRepMax]'s id keying is enough for the user's own workouts, but misses
/// on someone else's: a public workout's percentage set carries the *owner's*
/// exercise id, while the viewer's PR for the same lift hangs off their own
/// row — a different id for a lift of the same name (that's exactly what
/// `ExercisesNotifier.ensureExerciseByName` creates when a viewer sets a PR
/// from a read-only workout). Matching on name bridges the two so the preview
/// starts resolving instead of offering "set PR" forever.
@Riverpod(keepAlive: true)
Future<Map<String, OneRepMax>> oneRepMaxByName(Ref ref) async {
  ref.watch(authStateProvider);
  final formula = ref.watch(oneRepMaxFormulaProvider);
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return {};

  final data = await Supabase.instance.client
      .from('personal_bests')
      .select('weight_kg, reps, date, created_at, exercises(name)')
      .eq('user_id', userId);

  final rows = <OneRepMaxRow>[];
  for (final row in data as List) {
    final name = (row['exercises'] as Map<String, dynamic>?)?['name'] as String?;
    if (name == null || name.isEmpty) continue;
    rows.add((
      key: name.toLowerCase(),
      weightKg: (row['weight_kg'] as num).toDouble(),
      reps: (row['reps'] as num).toInt(),
      date: DateTime.parse(row['date'] as String),
      createdAt: DateTime.parse(row['created_at'] as String),
    ));
  }
  return foldOneRepMaxes(rows, formula);
}
