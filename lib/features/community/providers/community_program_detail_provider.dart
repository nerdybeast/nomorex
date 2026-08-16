import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../programs/models/program.dart';
import '../../auth/providers/auth_provider.dart';

part 'community_program_detail_provider.g.dart';

/// Full read-only tree for one public program, mirroring
/// [CommunityWorkoutDetailNotifier]. Deliberately separate from
/// `ProgramDetailNotifier`, which carries every authoring mutation — a viewer
/// looking at someone else's program should have no way to reach those.
@Riverpod(keepAlive: true)
class CommunityProgramDetailNotifier extends _$CommunityProgramDetailNotifier {
  SupabaseClient get _db => Supabase.instance.client;

  @override
  Future<Program> build(String programId) async {
    ref.watch(authStateProvider);
    final data = await _db
        .from('programs')
        .select('*, profiles(display_name), program_weeks(*, program_days(*, program_exercises('
            '*, exercises(name), program_sets(*, exercises(name)))))')
        .eq('id', programId)
        .single();
    return Program.fromJson(data);
  }
}
