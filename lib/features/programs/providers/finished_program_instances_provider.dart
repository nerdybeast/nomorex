import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/program_instance.dart';
import '../../auth/providers/auth_provider.dart';

part 'finished_program_instances_provider.g.dart';

/// Every ended (completed or abandoned) program run for the current user,
/// most recently ended first — backs the Program History screen. Mirror of
/// [CurrentProgramInstancesNotifier], which holds the active runs.
@Riverpod(keepAlive: true)
class FinishedProgramInstancesNotifier extends _$FinishedProgramInstancesNotifier {
  SupabaseClient get _db => Supabase.instance.client;

  @override
  Future<List<ProgramInstance>> build() async {
    ref.watch(authStateProvider);
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return [];

    final data = await _db
        .from('program_instances')
        .select(kProgramInstanceSelect)
        .eq('user_id', userId)
        .inFilter('status', ['completed', 'abandoned'])
        .order('completed_at', ascending: false, nullsFirst: false)
        .order('started_at', ascending: false);

    return (data as List)
        .map((e) => ProgramInstance.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
