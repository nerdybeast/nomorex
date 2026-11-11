/// One admin action (`admin_list_audit_log`).
class AdminAuditEntry {
  const AdminAuditEntry({
    required this.id,
    required this.action,
    required this.details,
    required this.createdAt,
    this.actorEmail,
    this.targetEmail,
  });

  final String id;
  final String action;

  /// Null once the acting user's account is deleted.
  final String? actorEmail;

  /// Null for actions without a target user, or once that account is deleted.
  final String? targetEmail;
  final Map<String, dynamic> details;
  final DateTime createdAt;

  factory AdminAuditEntry.fromJson(Map<String, dynamic> json) => AdminAuditEntry(
        id: json['id'] as String,
        action: json['action'] as String,
        actorEmail: json['actor_email'] as String?,
        targetEmail: json['target_email'] as String?,
        details: Map<String, dynamic>.from(json['details'] as Map? ?? const {}),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
