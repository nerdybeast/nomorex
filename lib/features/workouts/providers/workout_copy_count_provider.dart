import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/providers/auth_provider.dart';

part 'workout_copy_count_provider.g.dart';

/// How many (non-archived) copies of another user's public workout the viewer
/// has saved — drives the "You've saved this" hint on the community screen.
/// Invalidated as a whole family by WorkoutsNotifier.saveCommunityWorkout,
/// archiveWorkout, restoreWorkout and deleteWorkoutPermanently, so the hint
/// can't outlive an archived or deleted copy.
@Riverpod(keepAlive: true)
Future<int> workoutCopyCount(Ref ref, String sourceWorkoutId) async {
  ref.watch(authStateProvider);
  final db = Supabase.instance.client;
  final userId = db.auth.currentUser?.id;
  if (userId == null) return 0;

  final data = await db
      .from('workouts')
      .select('id')
      .eq('user_id', userId)
      .eq('copied_from_workout_id', sourceWorkoutId)
      .eq('is_archived', false);
  return (data as List).length;
}
