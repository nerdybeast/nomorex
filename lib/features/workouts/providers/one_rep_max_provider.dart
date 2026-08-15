import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/providers/auth_provider.dart';

part 'one_rep_max_provider.g.dart';

/// exerciseId -> the user's heaviest recorded 1-rep PR (kg) for that lift.
@Riverpod(keepAlive: true)
Future<Map<String, double>> oneRepMax(Ref ref) async {
  ref.watch(authStateProvider);
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return {};

  final data = await Supabase.instance.client
      .from('personal_bests')
      .select('exercise_id, weight_kg')
      .eq('user_id', userId)
      .eq('reps', 1);

  final maxes = <String, double>{};
  for (final row in data as List) {
    final id = row['exercise_id'] as String;
    final w = (row['weight_kg'] as num).toDouble();
    if (w > (maxes[id] ?? 0)) maxes[id] = w;
  }
  return maxes;
}

/// Lowercased exercise name -> the user's heaviest recorded 1-rep PR (kg).
///
/// [oneRepMax]'s id keying is enough for the user's own workouts, but misses
/// on someone else's: a public workout's percentage set carries the *owner's*
/// exercise id, while the viewer's PR for the same lift hangs off their own
/// row — a different id for a lift of the same name (that's exactly what
/// `ExercisesNotifier.ensureExerciseByName` creates when a viewer sets a PR
/// from a read-only workout). Matching on name bridges the two so the preview
/// starts resolving instead of offering "set PR" forever.
@Riverpod(keepAlive: true)
Future<Map<String, double>> oneRepMaxByName(Ref ref) async {
  ref.watch(authStateProvider);
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return {};

  final data = await Supabase.instance.client
      .from('personal_bests')
      .select('weight_kg, exercises(name)')
      .eq('user_id', userId)
      .eq('reps', 1);

  final maxes = <String, double>{};
  for (final row in data as List) {
    final name = (row['exercises'] as Map<String, dynamic>?)?['name'] as String?;
    if (name == null || name.isEmpty) continue;
    final key = name.toLowerCase();
    final w = (row['weight_kg'] as num).toDouble();
    if (w > (maxes[key] ?? 0)) maxes[key] = w;
  }
  return maxes;
}
