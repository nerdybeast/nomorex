/// Role names, as stored in `public.roles` / `public.user_roles`.
///
/// Roles are plain strings rather than an enum so a role added on the server
/// (a new `roles` row) doesn't break an app that doesn't know it yet.
abstract final class AppRoles {
  static const admin = 'admin';
}
