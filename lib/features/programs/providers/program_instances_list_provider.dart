import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/program_instance.dart';
import '../../auth/providers/auth_provider.dart';

part 'program_instances_list_provider.g.dart';

/// Active program runs for the current user — what the dashboard's "Current
/// Programs" section reads from. Excludes completed/abandoned instances.
@Riverpod(keepAlive: true)
class CurrentProgramInstancesNotifier extends _$CurrentProgramInstancesNotifier {
  SupabaseClient get _db => Supabase.instance.client;

  @override
  Future<List<ProgramInstance>> build() async {
    ref.watch(authStateProvider);
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return [];

    final data = await _db
        .from('program_instances')
        .select('*, programs(name)')
        .eq('user_id', userId)
        .eq('status', 'active')
        .order('started_at');

    return (data as List)
        .map((e) => ProgramInstance.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
