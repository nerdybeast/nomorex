import '../models/admin_audit_entry.dart';

/// One audit entry as a sentence, e.g. "a@a.com gave b@b.com the admin role".
String describeAuditEntry(AdminAuditEntry entry) {
  final actor = entry.actorEmail ?? 'A deleted user';
  final target = entry.targetEmail ?? 'a deleted user';
  final role = entry.details['role'] as String? ?? 'unknown';
  final exercise = entry.details['name'] as String? ?? 'an exercise';
  return switch (entry.action) {
    'role_granted' => '$actor gave $target the $role role',
    'role_revoked' => '$actor removed the $role role from $target',
    'ai_imports_enabled' => '$actor turned AI imports on',
    'ai_imports_disabled' => '$actor turned AI imports off',
    'exercise_created' => '$actor added the exercise $exercise',
    'exercise_updated' => switch (entry.details['old_name']) {
        final String old when old != exercise => '$actor renamed the exercise $old to $exercise',
        _ => "$actor changed $exercise's other names",
      },
    'exercise_retired' => '$actor retired the exercise $exercise',
    'exercise_restored' => '$actor restored the exercise $exercise',
    'exercise_deleted' => '$actor deleted the exercise $exercise',
    // An action added on the server before the app knows how to word it.
    final action => '$actor: ${action.replaceAll('_', ' ')}',
  };
}
