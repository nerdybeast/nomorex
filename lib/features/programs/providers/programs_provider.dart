import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/program.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/sequential_naming.dart';

part 'programs_provider.g.dart';

@Riverpod(keepAlive: true)
class ProgramsNotifier extends _$ProgramsNotifier {
  SupabaseClient get _db => Supabase.instance.client;

  @override
  Future<List<Program>> build() async {
    ref.watch(authStateProvider);
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return [];

    // Shallow: program + its weeks (no days/exercises/sets) for a "N weeks" count/summary.
    final data = await _db
        .from('programs')
        .select('*, program_weeks(*)')
        .eq('user_id', userId)
        .eq('is_archived', false)
        .order('created_at', ascending: false);

    return (data as List)
        .map((e) => Program.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<String> createProgram({
    required String name,
    String? description,
    bool isPublic = false,
  }) async {
    final userId = _db.auth.currentUser!.id;
    final row = await _db.from('programs').insert({
      'user_id': userId,
      'name': name,
      if (description != null && description.isNotEmpty) 'description': description,
      'is_public': isPublic,
    }).select('id').single();

    ref.invalidateSelf();
    await future;
    return row['id'] as String;
  }

  Future<void> archiveProgram(String id) async {
    await _db.from('programs').update({
      'is_archived': true,
      'archived_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
    ref.invalidate(archivedProgramsProvider);
    ref.invalidateSelf();
    await future;
  }

  Future<void> restoreProgram(String id) async {
    await _db.from('programs').update({
      'is_archived': false,
      'archived_at': null,
    }).eq('id', id);
    ref.invalidate(archivedProgramsProvider);
    ref.invalidateSelf();
    await future;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

/// Mirrors [ProgramsNotifier] but surfaces the archived list, so a user can
/// find and restore a program they archived. No hard delete is ever
/// exposed — see `programs.is_archived` in the Phase 3 migration.
@Riverpod(keepAlive: true)
class ArchivedProgramsNotifier extends _$ArchivedProgramsNotifier {
  SupabaseClient get _db => Supabase.instance.client;

  @override
  Future<List<Program>> build() async {
    ref.watch(authStateProvider);
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return [];

    final data = await _db
        .from('programs')
        .select()
        .eq('user_id', userId)
        .eq('is_archived', true)
        .order('archived_at', ascending: false);

    return (data as List)
        .map((e) => Program.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

/// "Program N" where N is one past the highest numbered program name the
/// user has — including archived ones, since programs are never hard-deleted
/// (see [ArchivedProgramsNotifier]), so a freed-up number could otherwise
/// collide with an existing archived program's name.
@riverpod
Future<String> nextProgramName(Ref ref) async {
  ref.watch(authStateProvider);
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return 'Program 1';

  final data = await Supabase.instance.client
      .from('programs')
      .select('name')
      .eq('user_id', userId);

  final names = (data as List).map((e) => e['name'] as String);
  return nextSequentialName(names, 'Program');
}
