import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'finished_program_instances_provider.dart';
import 'program_instance_detail_provider.dart';
import 'program_instances_list_provider.dart';

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
    ref.invalidate(currentProgramInstancesProvider);
    return instanceId;
  }

  Future<void> completeProgramInstance(String id) => _endInstance(id, 'completed');

  Future<void> abandonProgramInstance(String id) => _endInstance(id, 'abandoned');

  /// Ends a run and refreshes every provider that renders it: the active
  /// list (dashboard + Programs tile status), the history list, and the
  /// instance's own detail.
  Future<void> _endInstance(String id, String status) async {
    await _db.from('program_instances').update({
      'status': status,
      'completed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
    ref.invalidate(currentProgramInstancesProvider);
    ref.invalidate(finishedProgramInstancesProvider);
    ref.invalidate(programInstanceDetailProvider(id));
  }
}
