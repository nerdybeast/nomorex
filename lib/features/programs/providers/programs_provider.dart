import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/program.dart';
import '../../auth/providers/auth_provider.dart';
import '../../exercises/providers/exercises_provider.dart';
import '../../../core/utils/sequential_naming.dart';
import 'program_copy_count_provider.dart';
import 'program_detail_provider.dart';
import 'program_instances_list_provider.dart';

part 'programs_provider.g.dart';

@Riverpod(keepAlive: true)
class ProgramsNotifier extends _$ProgramsNotifier {
  SupabaseClient get _db => Supabase.instance.client;

  @override
  Future<List<Program>> build() async {
    ref.watch(authStateProvider);
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return [];

    // Shallow: program + its weeks and day rows (no exercises/sets) for the
    // "N weeks" / "N training days" summary.
    final data = await _db
        .from('programs')
        .select('*, program_weeks(*, program_days(*))')
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
    // The detail screen turns read-only for an archived program.
    ref.invalidate(programDetailProvider(id));
    // Archived copies don't count toward the community "saved" hint.
    ref.invalidate(programCopyCountProvider);
    ref.invalidateSelf();
    await future;
  }

  Future<void> restoreProgram(String id) async {
    await _db.from('programs').update({
      'is_archived': false,
      'archived_at': null,
    }).eq('id', id);
    ref.invalidate(archivedProgramsProvider);
    ref.invalidate(programDetailProvider(id));
    ref.invalidate(programCopyCountProvider);
    ref.invalidateSelf();
    await future;
  }

  /// Saves a copy of another user's public program into the viewer's own
  /// programs and, with [startDate], starts a run of the copy — one
  /// transaction via the `copy_program` RPC, which reuses `start_program` so
  /// scheduling matches starting your own program. Exercises are mapped into
  /// the viewer's catalog by name (this can create custom exercises).
  Future<({String programId, String? instanceId})> saveCommunityProgram(
    String sourceProgramId, {
    DateTime? startDate,
  }) async {
    final result = await _db.rpc('copy_program', params: {
      'p_source_program_id': sourceProgramId,
      'p_start_date': startDate?.toIso8601String().substring(0, 10),
    }) as Map<String, dynamic>;

    ref.invalidate(exercisesProvider);
    ref.invalidate(programCopyCountProvider);
    if (startDate != null) ref.invalidate(currentProgramInstancesProvider);
    ref.invalidateSelf();
    await future;
    return (
      programId: result['program_id'] as String,
      instanceId: result['instance_id'] as String?,
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

/// Mirrors [ProgramsNotifier] but surfaces the archived list, so a user can
/// find and restore a program they archived. Unlike workouts, no hard delete
/// is ever exposed — see `programs.is_archived` in the Phase 3 migration.
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
