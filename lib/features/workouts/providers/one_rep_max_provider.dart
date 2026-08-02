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
