import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../workouts/models/workout.dart';
import '../../auth/providers/auth_provider.dart';

part 'community_workouts_provider.g.dart';

@Riverpod(keepAlive: true)
class CommunityWorkoutsNotifier extends _$CommunityWorkoutsNotifier {
  SupabaseClient get _db => Supabase.instance.client;

  @override
  Future<List<Workout>> build() async {
    ref.watch(authStateProvider);
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return [];

    final data = await _db
        .from('workouts')
        .select('*, profiles(display_name), workout_exercises(*, exercises(name))')
        .eq('is_public', true)
        .neq('user_id', userId)
        .order('date', ascending: false);

    return (data as List)
        .map((e) => Workout.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
