import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:nomorex/features/admin/models/admin_user.dart';
import 'package:nomorex/features/admin/models/app_roles.dart';
import 'package:nomorex/features/admin/providers/admin_users_provider.dart';
import 'package:nomorex/features/admin/providers/current_roles_provider.dart';
import 'package:nomorex/features/auth/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stands in for the admin_* functions: [count] users `user0@example.com`…,
/// newest first. user0 is the signed-in admin; every third user is an admin.
class FakeAdminServer {
  FakeAdminServer({int count = 60}) {
    for (var i = 0; i < count; i++) {
      users.add({
        'id': 'u$i',
        'email': 'user$i@example.com',
        'display_name': i.isEven ? 'Lifter $i' : null,
        'roles': i % 3 == 0 ? [AppRoles.admin] : <String>[],
        'created_at': DateTime.utc(2026, 10, 1).subtract(Duration(days: i)).toIso8601String(),
        'last_sign_in_at': i == 1 ? null : '2026-11-10T12:00:00Z',
      });
    }
  }

  final users = <Map<String, dynamic>>[];
  final audit = <Map<String, dynamic>>[];
  final rpcCalls = <(String, Map<String, dynamic>)>[];

  /// Thrown by the next role change instead of saving, when set.
  Object? error;

  List<Map<String, dynamic>> page(List<Map<String, dynamic>> rows, int limit, int offset) => [
        for (final row in rows.skip(offset).take(limit)) {...row, 'total_count': rows.length},
      ];
}

const kSignedInAdmin = User(
  id: 'u0',
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  email: 'user0@example.com',
  createdAt: '2026-01-01T00:00:00Z',
);

List<Override> adminUsersOverrides(FakeAdminServer server) => [
      currentAuthUserProvider.overrideWithValue(kSignedInAdmin),
      currentUserRolesProvider.overrideWith((ref) async => {AppRoles.admin}),
      availableRolesProvider.overrideWith(
        (ref) async => const [RoleInfo(name: AppRoles.admin, description: 'Manages users, their roles and app settings.')],
      ),
      adminUsersProvider.overrideWith(() => _FakeAdminUsersNotifier(server)),
      adminAuditLogProvider.overrideWith(() => _FakeAdminAuditLogNotifier(server)),
      adminRolesProvider.overrideWith(() => _FakeAdminRolesNotifier(server)),
    ];

class _FakeAdminUsersNotifier extends AdminUsersNotifier {
  _FakeAdminUsersNotifier(this.server);
  final FakeAdminServer server;

  @override
  Future<List<Map<String, dynamic>>> fetchRows(String search, int limit, int offset) async {
    final needle = search.toLowerCase();
    final matches = [
      for (final user in server.users)
        if ((user['email'] as String).contains(needle) ||
            ((user['display_name'] as String?)?.toLowerCase().contains(needle) ?? false))
          user,
    ];
    return server.page(matches, limit, offset);
  }
}

class _FakeAdminAuditLogNotifier extends AdminAuditLogNotifier {
  _FakeAdminAuditLogNotifier(this.server);
  final FakeAdminServer server;

  @override
  Future<List<Map<String, dynamic>>> fetchRows(int limit, int offset) async => server.page(server.audit, limit, offset);
}

class _FakeAdminRolesNotifier extends AdminRolesNotifier {
  _FakeAdminRolesNotifier(this.server);
  final FakeAdminServer server;

  @override
  Future<void> callRpc(String function, Map<String, dynamic> params) async {
    server.rpcCalls.add((function, params));
    final error = server.error;
    if (error != null) throw error;
    final user = server.users.firstWhere((u) => u['id'] == params['p_user_id']);
    final roles = {...(user['roles'] as List).cast<String>()};
    function == 'admin_grant_role' ? roles.add(params['p_role'] as String) : roles.remove(params['p_role']);
    user['roles'] = roles.toList();
  }
}
