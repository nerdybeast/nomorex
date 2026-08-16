import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../programs/models/program.dart';
import '../../auth/providers/auth_provider.dart';

part 'community_programs_provider.g.dart';

/// Public programs authored by *other* users, mirroring
/// [CommunityWorkoutsNotifier]. Shallow like `ProgramsNotifier`: weeks only, so
/// the list can show a "N weeks" summary without pulling every day and set.
@Riverpod(keepAlive: true)
class CommunityProgramsNotifier extends _$CommunityProgramsNotifier {
  SupabaseClient get _db => Supabase.instance.client;

  @override
  Future<List<Program>> build() async {
    ref.watch(authStateProvider);
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return [];

    final data = await _db
        .from('programs')
        .select('*, profiles(display_name), program_weeks(*)')
        .eq('is_public', true)
        // Archiving is the app's stand-in for deleting a program, so an
        // archived one must not stay browsable just because it was public.
        .eq('is_archived', false)
        .neq('user_id', userId)
        .order('created_at', ascending: false);

    return (data as List)
        .map((e) => Program.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
