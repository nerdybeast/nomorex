import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/workout.dart';
import '../../auth/providers/auth_provider.dart';

part 'in_progress_workouts_provider.g.dart';

/// Workouts currently in progress or paused for the current user — what the
/// dashboard's "Workouts In Progress" section reads from. Unlike
/// [workoutsProvider], this deliberately does NOT exclude workouts
/// materialized from a program: a program-originated workout that's
/// actively in progress should still surface on the dashboard.
@Riverpod(keepAlive: true)
class InProgressWorkoutsNotifier extends _$InProgressWorkoutsNotifier {
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
        .inFilter('status', ['in_progress', 'paused'])
        .order('started_at');

    return (data as List)
        .map((e) => Workout.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
