/// One row of the admin users table (`admin_list_users`).
class AdminUser {
  const AdminUser({
    required this.id,
    required this.email,
    required this.roles,
    required this.createdAt,
    this.displayName,
    this.lastSignInAt,
  });

  final String id;

  /// Empty for an account with no email (none exist today, but auth allows it).
  final String email;
  final String? displayName;
  final List<String> roles;
  final DateTime createdAt;

  /// Null if the user has never signed in.
  final DateTime? lastSignInAt;

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
        id: json['id'] as String,
        email: json['email'] as String? ?? '',
        displayName: json['display_name'] as String?,
        roles: [for (final role in json['roles'] as List? ?? const []) role as String],
        createdAt: DateTime.parse(json['created_at'] as String),
        lastSignInAt: json['last_sign_in_at'] == null ? null : DateTime.parse(json['last_sign_in_at'] as String),
      );
}

/// A role a user can be given (`public.roles`).
class RoleInfo {
  const RoleInfo({required this.name, required this.description});

  final String name;
  final String description;

  factory RoleInfo.fromJson(Map<String, dynamic> json) =>
      RoleInfo(name: json['name'] as String, description: json['description'] as String);
}

/// One page of a paginated admin list. [total] counts every match, not just
/// this page.
class AdminPage<T> {
  const AdminPage({required this.items, required this.total, required this.page, required this.pageSize});

  final List<T> items;
  final int total;
  final int page;
  final int pageSize;

  int get firstIndex => page * pageSize;
  bool get hasPrevious => page > 0;
  bool get hasNext => firstIndex + items.length < total;
}

const kAdminPageSize = 25;
