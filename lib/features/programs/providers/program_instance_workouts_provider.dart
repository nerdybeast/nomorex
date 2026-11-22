import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/providers/auth_provider.dart';
import '../utils/program_stats.dart';

part 'program_instance_workouts_provider.g.dart';

/// Maps a program instance's materialized workouts back to the session each
/// one was generated from (`workoutKey`: its `program_session_id`, or its
/// `program_day_id` when it has none), so a day's session rows can push
/// straight to the real, loggable workout.
@Riverpod(keepAlive: true)
class ProgramInstanceWorkoutsNotifier extends _$ProgramInstanceWorkoutsNotifier {
  SupabaseClient get _db => Supabase.instance.client;

  @override
  Future<Map<String, String>> build(String instanceId) async {
    ref.watch(authStateProvider);
    final data = await _db
        .from('workouts')
        .select('id, program_day_id, program_session_id')
        .eq('program_instance_id', instanceId);

    return {
      for (final row in data as List)
        ?workoutKey(row as Map<String, dynamic>): row['id'] as String,
    };
  }
}
