import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../../exercises/providers/exercises_provider.dart';
import '../../workouts/providers/one_rep_max_provider.dart';
import '../models/admin_exercise.dart';
import '../models/admin_user.dart';
import 'admin_users_provider.dart';

part 'admin_exercises_provider.g.dart';

/// One page of official exercises A–Z, active or [retired], matching [search]
/// (name, alias or slug). Re-read on every visit, like the users list.
@riverpod
class AdminExercisesNotifier extends _$AdminExercisesNotifier {
  @override
  Future<AdminPage<AdminExercise>> build({required String search, required bool retired, required int page}) async {
    final user = ref.watch(currentAuthUserProvider);
    if (user == null) return AdminPage(items: const [], total: 0, page: page, pageSize: kAdminPageSize);
    final rows = await fetchRows(search, retired, kAdminPageSize, page * kAdminPageSize);
    return AdminPage(
      items: [for (final row in rows) AdminExercise.fromJson(row)],
      total: rows.isEmpty ? 0 : (rows.first['total_count'] as num).toInt(),
      page: page,
      pageSize: kAdminPageSize,
    );
  }

  // Network call, split out so tests can override it.
  Future<List<Map<String, dynamic>>> fetchRows(String search, bool retired, int limit, int offset) async {
    final rows = await Supabase.instance.client.rpc('admin_list_exercises', params: {
      'p_search': search,
      'p_retired': retired,
      'p_limit': limit,
      'p_offset': offset,
    });
    return [for (final row in rows as List) Map<String, dynamic>.from(row as Map)];
  }
}

/// Creates, edits, retires, restores, deletes and exports official exercises.
/// Loading while a change is saved; each change rethrows on failure after
/// leaving the error in its state.
///
/// After a change it re-reads the admin lists, the audit log, and this
/// device's exercise catalog and name-keyed 1RMs (aliases are keys there).
/// Workout and program lists cache exercise names too and show a rename the
/// next time they load; other users see every change on their next load.
@riverpod
class AdminExerciseActionsNotifier extends _$AdminExerciseActionsNotifier {
  @override
  FutureOr<void> build() {}

  /// Returns how many lifters already have a custom exercise answering to one
  /// of the new exercise's names.
  Future<int> create({required String slug, required String name, required List<String> aliases}) async {
    final rows = await _run(() => callRpc('admin_create_exercise', {
          'p_slug': slug,
          'p_name': name,
          'p_aliases': aliases,
        }));
    final list = rows as List? ?? const [];
    return list.isEmpty ? 0 : ((list.first as Map)['custom_name_count'] as num).toInt();
  }

  Future<void> edit(String id, {required String name, required List<String> aliases}) =>
      _run(() => callRpc('admin_update_exercise', {'p_exercise_id': id, 'p_name': name, 'p_aliases': aliases}));

  Future<void> setRetired(String id, bool retired) =>
      _run(() => callRpc('admin_set_exercise_retired', {'p_exercise_id': id, 'p_retired': retired}));

  Future<void> delete(String id) => _run(() => callRpc('admin_delete_exercise', {'p_exercise_id': id}));

  /// The catalog file's contents (`supabase/catalog/official_exercises.sql`).
  /// Read-only, so it doesn't touch [state].
  Future<String> export() async => await callRpc('admin_export_exercises', const {}) as String;

  Future<T> _run<T>(Future<T> Function() call) async {
    state = const AsyncLoading();
    try {
      final result = await call();
      ref.invalidate(adminExercisesProvider);
      ref.invalidate(adminAuditLogProvider);
      ref.invalidate(exercisesProvider);
      ref.invalidate(oneRepMaxByNameProvider);
      state = const AsyncData(null);
      return result;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  // Network call, split out so tests can override it.
  Future<dynamic> callRpc(String fn, Map<String, dynamic> params) =>
      Supabase.instance.client.rpc(fn, params: params);
}
