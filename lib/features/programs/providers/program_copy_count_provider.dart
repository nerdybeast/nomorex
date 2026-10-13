import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/providers/auth_provider.dart';

part 'program_copy_count_provider.g.dart';

/// How many (non-archived) copies of another user's public program the viewer
/// has saved — drives the "You've saved this" hint on the community screen.
/// Invalidated as a whole family by ProgramsNotifier.saveCommunityProgram,
/// archiveProgram and restoreProgram.
@Riverpod(keepAlive: true)
Future<int> programCopyCount(Ref ref, String sourceProgramId) async {
  ref.watch(authStateProvider);
  final db = Supabase.instance.client;
  final userId = db.auth.currentUser?.id;
  if (userId == null) return 0;

  final data = await db
      .from('programs')
      .select('id')
      .eq('user_id', userId)
      .eq('is_archived', false)
      .eq('copied_from_program_id', sourceProgramId);
  return (data as List).length;
}
