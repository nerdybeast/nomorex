import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/admin_audit_entry.dart';
import '../models/admin_user.dart';
import 'current_roles_provider.dart';

part 'admin_users_provider.g.dart';

/// One page of users matching [search] (email or display name), newest first.
/// Re-read on every visit rather than kept alive: admins expect a fresh list.
@riverpod
class AdminUsersNotifier extends _$AdminUsersNotifier {
  @override
  Future<AdminPage<AdminUser>> build({required String search, required int page}) async {
    final user = ref.watch(currentAuthUserProvider);
    if (user == null) return AdminPage(items: const [], total: 0, page: page, pageSize: kAdminPageSize);
    final rows = await fetchRows(search, kAdminPageSize, page * kAdminPageSize);
    return AdminPage(
      items: [for (final row in rows) AdminUser.fromJson(row)],
      // Every row carries the total; a page past the end has no rows, so none.
      total: rows.isEmpty ? 0 : (rows.first['total_count'] as num).toInt(),
      page: page,
      pageSize: kAdminPageSize,
    );
  }

  // Network call, split out so tests can override it.
  Future<List<Map<String, dynamic>>> fetchRows(String search, int limit, int offset) async {
    final rows = await Supabase.instance.client.rpc('admin_list_users', params: {
      'p_search': search,
      'p_limit': limit,
      'p_offset': offset,
    });
    return [for (final row in rows as List) Map<String, dynamic>.from(row as Map)];
  }
}

/// One page of the admin audit log, newest first.
@riverpod
class AdminAuditLogNotifier extends _$AdminAuditLogNotifier {
  @override
  Future<AdminPage<AdminAuditEntry>> build({required int page}) async {
    final user = ref.watch(currentAuthUserProvider);
    if (user == null) return AdminPage(items: const [], total: 0, page: page, pageSize: kAdminPageSize);
    final rows = await fetchRows(kAdminPageSize, page * kAdminPageSize);
    return AdminPage(
      items: [for (final row in rows) AdminAuditEntry.fromJson(row)],
      total: rows.isEmpty ? 0 : (rows.first['total_count'] as num).toInt(),
      page: page,
      pageSize: kAdminPageSize,
    );
  }

  // Network call, split out so tests can override it.
  Future<List<Map<String, dynamic>>> fetchRows(int limit, int offset) async {
    final rows = await Supabase.instance.client.rpc('admin_list_audit_log', params: {
      'p_limit': limit,
      'p_offset': offset,
    });
    return [for (final row in rows as List) Map<String, dynamic>.from(row as Map)];
  }
}

/// Every role a user can be given, for the switches on a user's details. A
/// role added on the server shows up here with no app change.
@Riverpod(keepAlive: true)
Future<List<RoleInfo>> availableRoles(Ref ref) async {
  final user = ref.watch(currentAuthUserProvider);
  if (user == null) return const [];
  final rows = await Supabase.instance.client.from('roles').select('name, description').order('name');
  return [for (final row in rows) RoleInfo.fromJson(row)];
}

/// Grants and revokes roles. Loading while a change is saved; rethrows on
/// failure after leaving the error in its state.
@riverpod
class AdminRolesNotifier extends _$AdminRolesNotifier {
  @override
  FutureOr<void> build() {}

  Future<void> grant(String userId, String role) =>
      _change(() => callRpc('admin_grant_role', {'p_user_id': userId, 'p_role': role}));

  Future<void> revoke(String userId, String role) =>
      _change(() => callRpc('admin_revoke_role', {'p_user_id': userId, 'p_role': role}));

  Future<void> _change(Future<void> Function() call) async {
    state = const AsyncLoading();
    try {
      await call();
      // The users table shows roles, the audit log gains an entry, and an
      // admin may have changed their own roles.
      ref.invalidate(adminUsersProvider);
      ref.invalidate(adminAuditLogProvider);
      ref.invalidate(currentUserRolesProvider);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  // Network call, split out so tests can override it.
  Future<void> callRpc(String function, Map<String, dynamic> params) =>
      Supabase.instance.client.rpc(function, params: params);
}
