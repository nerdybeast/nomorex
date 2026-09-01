import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../../../core/utils/one_rep_max_formula.dart';
import '../../../shared/models/one_rep_max.dart';

part 'one_rep_max_provider.g.dart';

/// Folds `personal_bests` rows into one [OneRepMax] per key.
///
/// A measured single always wins: the estimate is only ever a stand-in for a
/// lifter who has never tested one. Rows outside the formulas' usable rep
/// range contribute nothing, so a key with only 20-rep PRs is absent from the
/// map entirely — the same "no 1RM" state as having no PRs at all.
Map<String, OneRepMax> _foldOneRepMaxes(
  Iterable<({String key, double weightKg, int reps})> rows,
  OneRepMaxFormula formula,
) {
  final measured = <String, double>{};
  final estimated = <String, double>{};

  for (final row in rows) {
    if (row.reps == 1) {
      if (row.weightKg > (measured[row.key] ?? 0)) measured[row.key] = row.weightKg;
      continue;
    }
    final est = estimateOneRepMaxKg(
      weightKg: row.weightKg,
      reps: row.reps,
      formula: formula,
    );
    if (est == null) continue;
    if (est > (estimated[row.key] ?? 0)) estimated[row.key] = est;
  }

  return {
    for (final key in {...measured.keys, ...estimated.keys})
      key: measured.containsKey(key)
          ? OneRepMax.measured(measured[key]!)
          : OneRepMax.estimated(estimated[key]!),
  };
}

/// exerciseId -> the user's 1RM (kg) for that lift: their heaviest recorded
/// single, or — when they've never tested one — the best estimate from their
/// multi-rep PRs.
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
      .select('exercise_id, weight_kg, reps')
      .eq('user_id', userId);

  return _foldOneRepMaxes(
    [
      for (final row in data as List)
        (
          key: row['exercise_id'] as String,
          weightKg: (row['weight_kg'] as num).toDouble(),
          reps: (row['reps'] as num).toInt(),
        ),
    ],
    formula,
  );
}

/// Lowercased exercise name -> the user's 1RM (kg), measured or estimated.
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
      .select('weight_kg, reps, exercises(name)')
      .eq('user_id', userId);

  final rows = <({String key, double weightKg, int reps})>[];
  for (final row in data as List) {
    final name = (row['exercises'] as Map<String, dynamic>?)?['name'] as String?;
    if (name == null || name.isEmpty) continue;
    rows.add((
      key: name.toLowerCase(),
      weightKg: (row['weight_kg'] as num).toDouble(),
      reps: (row['reps'] as num).toInt(),
    ));
  }
  return _foldOneRepMaxes(rows, formula);
}
