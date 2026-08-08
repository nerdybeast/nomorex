import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/providers/auth_provider.dart';

part 'program_instance_workouts_provider.g.dart';

/// Maps a program instance's materialized workouts back to the
/// `program_day_id` each one was generated from, so a day card can push
/// straight to the real, loggable workout for that day.
@Riverpod(keepAlive: true)
class ProgramInstanceWorkoutsNotifier extends _$ProgramInstanceWorkoutsNotifier {
  SupabaseClient get _db => Supabase.instance.client;

  @override
  Future<Map<String, String>> build(String instanceId) async {
    ref.watch(authStateProvider);
    final data = await _db
        .from('workouts')
        .select('id, program_day_id')
        .eq('program_instance_id', instanceId);

    return {
      for (final row in data as List)
        (row as Map<String, dynamic>)['program_day_id'] as String: row['id'] as String,
    };
  }
}
