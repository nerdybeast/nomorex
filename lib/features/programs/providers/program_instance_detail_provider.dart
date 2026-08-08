import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/program_instance.dart';
import '../../auth/providers/auth_provider.dart';

part 'program_instance_detail_provider.g.dart';

@Riverpod(keepAlive: true)
class ProgramInstanceDetailNotifier extends _$ProgramInstanceDetailNotifier {
  SupabaseClient get _db => Supabase.instance.client;

  @override
  Future<ProgramInstance> build(String instanceId) async {
    ref.watch(authStateProvider);
    final data = await _db
        .from('program_instances')
        .select('*, programs(name)')
        .eq('id', instanceId)
        .single();
    return ProgramInstance.fromJson(data);
  }
}
