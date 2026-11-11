import '../models/admin_audit_entry.dart';

/// One audit entry as a sentence, e.g. "a@a.com gave b@b.com the admin role".
String describeAuditEntry(AdminAuditEntry entry) {
  final actor = entry.actorEmail ?? 'A deleted user';
  final target = entry.targetEmail ?? 'a deleted user';
  final role = entry.details['role'] as String? ?? 'unknown';
  return switch (entry.action) {
    'role_granted' => '$actor gave $target the $role role',
    'role_revoked' => '$actor removed the $role role from $target',
    'ai_imports_enabled' => '$actor turned AI imports on',
    'ai_imports_disabled' => '$actor turned AI imports off',
    // An action added on the server before the app knows how to word it.
    final action => '$actor: ${action.replaceAll('_', ' ')}',
  };
}
