import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/workout.dart';
import '../../auth/providers/auth_provider.dart';

part 'finished_workouts_provider.g.dart';

/// Every finished workout for the current user, newest completion first —
/// backs both the dashboard's "Recent Workouts" section and the Workout
/// History screen (filtered client-side by workoutGroupId there). Unlike
/// [workoutsProvider], this deliberately does NOT exclude workouts
/// materialized from a program: a completed program-day workout is still a
/// completed workout for history/dashboard purposes.
@Riverpod(keepAlive: true)
class FinishedWorkoutsNotifier extends _$FinishedWorkoutsNotifier {
  SupabaseClient get _db => Supabase.instance.client;

  @override
  Future<List<Workout>> build() async {
    ref.watch(authStateProvider);
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return [];

    final data = await _db
        .from('workouts')
        .select('*, workout_exercises(*, exercises(name))')
        .eq('user_id', userId)
        .eq('status', 'finished')
        .order('finished_at', ascending: false);

    return (data as List)
        .map((e) => Workout.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
