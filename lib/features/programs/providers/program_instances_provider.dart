import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../workouts/providers/workouts_provider.dart';

part 'program_instances_provider.g.dart';

/// Action-only notifier (no state of its own) for the "Start Program" flow
/// and running-instance status updates — mirrors AuthNotifier's shape.
@Riverpod(keepAlive: true)
class ProgramInstancesNotifier extends _$ProgramInstancesNotifier {
  SupabaseClient get _db => Supabase.instance.client;

  @override
  void build() {}

  /// Materializes [programId] into logged workouts starting on [startDate],
  /// via the `start_program` RPC (one server-side transaction — see
  /// 20260805020858_create_start_program_function.sql). Returns the new
  /// program_instances id.
  Future<String> startProgram(String programId, DateTime startDate) async {
    final instanceId = await _db.rpc('start_program', params: {
      'p_program_id': programId,
      'p_start_date': startDate.toIso8601String().substring(0, 10),
    }) as String;
    ref.invalidate(workoutsProvider);
    return instanceId;
  }

  Future<void> completeProgramInstance(String id) async {
    await _db.from('program_instances').update({'status': 'completed'}).eq('id', id);
  }

  Future<void> abandonProgramInstance(String id) async {
    await _db.from('program_instances').update({'status': 'abandoned'}).eq('id', id);
  }
}
