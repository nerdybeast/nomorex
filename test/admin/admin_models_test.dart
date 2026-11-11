import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/admin/models/admin_audit_entry.dart';
import 'package:nomorex/features/admin/models/admin_user.dart';
import 'package:nomorex/features/admin/utils/audit_entry_text.dart';

void main() {
  group('AdminUser.fromJson', () {
    test('reads a row from admin_list_users', () {
      final user = AdminUser.fromJson({
        'id': 'u1',
        'email': 'a@a.com',
        'display_name': 'Alpha',
        'roles': ['admin'],
        'created_at': '2026-11-01T08:00:00+00:00',
        'last_sign_in_at': '2026-11-10T09:30:00+00:00',
        'total_count': 3,
      });
      expect(user.email, 'a@a.com');
      expect(user.displayName, 'Alpha');
      expect(user.roles, ['admin']);
      expect(user.createdAt, DateTime.utc(2026, 11, 1, 8));
      expect(user.lastSignInAt, DateTime.utc(2026, 11, 10, 9, 30));
    });

    test('a user who never signed in, with no name and no roles', () {
      final user = AdminUser.fromJson({
        'id': 'u2',
        'email': 'c@c.com',
        'display_name': null,
        'roles': <String>[],
        'created_at': '2026-11-01T08:00:00+00:00',
        'last_sign_in_at': null,
      });
      expect(user.displayName, isNull);
      expect(user.roles, isEmpty);
      expect(user.lastSignInAt, isNull);
    });
  });

  group('AdminPage', () {
    test('knows whether there is a page before and after', () {
      const first = AdminPage(items: [1, 2], total: 5, page: 0, pageSize: 2);
      const last = AdminPage(items: [5], total: 5, page: 2, pageSize: 2);
      expect((first.hasPrevious, first.hasNext), (false, true));
      expect((last.hasPrevious, last.hasNext), (true, false));
    });
  });

  group('describeAuditEntry', () {
    AdminAuditEntry entry(String action, {String? actor = 'a@a.com', String? target, Map<String, dynamic>? details}) =>
        AdminAuditEntry(
          id: 'e',
          action: action,
          actorEmail: actor,
          targetEmail: target,
          details: details ?? const {},
          createdAt: DateTime.utc(2026, 11, 11),
        );

    test('words each known action', () {
      expect(describeAuditEntry(entry('role_granted', target: 'b@b.com', details: {'role': 'admin'})),
          'a@a.com gave b@b.com the admin role');
      expect(describeAuditEntry(entry('role_revoked', target: 'b@b.com', details: {'role': 'admin'})),
          'a@a.com removed the admin role from b@b.com');
      expect(describeAuditEntry(entry('ai_imports_enabled')), 'a@a.com turned AI imports on');
      expect(describeAuditEntry(entry('ai_imports_disabled')), 'a@a.com turned AI imports off');
    });

    test('names deleted accounts and unknown actions without failing', () {
      expect(describeAuditEntry(entry('role_granted', actor: null, details: {'role': 'admin'})),
          'A deleted user gave a deleted user the admin role');
      expect(describeAuditEntry(entry('limits_changed')), 'a@a.com: limits changed');
    });
  });
}
