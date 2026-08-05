import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../workouts/models/workout.dart';
import '../../auth/providers/auth_provider.dart';

part 'community_workout_detail_provider.g.dart';

@Riverpod(keepAlive: true)
class CommunityWorkoutDetailNotifier extends _$CommunityWorkoutDetailNotifier {
  SupabaseClient get _db => Supabase.instance.client;

  @override
  Future<Workout> build(String workoutId) async {
    ref.watch(authStateProvider);
    final data = await _db
        .from('workouts')
        .select('*, workout_exercises(*, exercises(name), workout_sets(*, exercises(name)))')
        .eq('id', workoutId)
        .single();
    return Workout.fromJson(data);
  }
}
