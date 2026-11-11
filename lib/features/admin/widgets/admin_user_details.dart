import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/admin_user.dart';
import '../models/app_roles.dart';
import '../providers/admin_users_provider.dart';
import '../utils/admin_error.dart';

/// Opens [user]'s details: a bottom sheet on a phone, a dialog on a wider
/// screen.
Future<void> showAdminUserDetails(BuildContext context, AdminUser user) {
  if (isMobile(context)) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: AdminUserDetails(user: user),
        ),
      ),
    );
  }
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: SizedBox(width: 440, child: AdminUserDetails(user: user)),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
    ),
  );
}

/// A user's account details and one switch per role. The switches sit beside
/// their labels in a `Row`, not in a `ListTile`, so each stays its own
/// semantics node.
class AdminUserDetails extends ConsumerStatefulWidget {
  const AdminUserDetails({super.key, required this.user});

  final AdminUser user;

  @override
  ConsumerState<AdminUserDetails> createState() => _AdminUserDetailsState();
}

class _AdminUserDetailsState extends ConsumerState<AdminUserDetails> {
  /// The user's roles as last saved, so a switch moves without waiting for the
  /// list behind this panel to reload.
  late final Set<String> _roles = widget.user.roles.toSet();
  String? _error;

  Future<void> _change(String role, bool grant) async {
    final email = widget.user.email;
    final confirmed = await showConfirmDialog(
      context,
      title: grant ? 'Give $email the $role role?' : 'Remove the $role role from $email?',
      message: switch ((role, grant)) {
        (AppRoles.admin, true) => "They'll be able to see every user, change roles and turn app features on or off.",
        (AppRoles.admin, false) => "They'll lose access to the Admin area straight away.",
        _ => 'You can change this again at any time.',
      },
      confirmLabel: grant ? 'Give role' : 'Remove role',
    );
    if (!confirmed || !mounted) return;
    setState(() => _error = null);
    final notifier = ref.read(adminRolesProvider.notifier);
    try {
      grant ? await notifier.grant(widget.user.id, role) : await notifier.revoke(widget.user.id, role);
      if (mounted) setState(() => grant ? _roles.add(role) : _roles.remove(role));
    } catch (e) {
      if (mounted) setState(() => _error = adminErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final theme = Theme.of(context);
    final tokens = NomorexTokens.of(context);
    final isSelf = ref.watch(currentAuthUserProvider)?.id == user.id;
    final saving = ref.watch(adminRolesProvider).isLoading;
    final roles = ref.watch(availableRolesProvider);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(user.email.isEmpty ? 'No email' : user.email, style: theme.textTheme.titleMedium),
          if (user.displayName != null)
            Text(user.displayName!, style: theme.textTheme.bodyMedium?.copyWith(color: tokens.fg2)),
          const SizedBox(height: 12),
          Text('Joined ${formatDate(user.createdAt.toLocal())}', style: theme.textTheme.bodySmall),
          Text(
            user.lastSignInAt == null
                ? 'Never signed in'
                : 'Last signed in ${formatDate(user.lastSignInAt!.toLocal())}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          Text('ROLES', style: tokens.eyebrow),
          const SizedBox(height: 8),
          switch (roles) {
            AsyncValue(:final value?) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final role in value)
                    _RoleRow(
                      role: role,
                      value: _roles.contains(role.name),
                      // Removing your own role is refused by the server too.
                      lockedReason: isSelf && _roles.contains(role.name)
                          ? "You can't remove your own ${role.name} role."
                          : null,
                      onChanged: saving ? null : (grant) => _change(role.name, grant),
                    ),
                ],
              ),
            AsyncError() => Text("Couldn't load the roles.", style: TextStyle(color: theme.colorScheme.error)),
            _ => const Padding(
                padding: EdgeInsets.all(8),
                child: Center(child: CircularProgressIndicator()),
              ),
          },
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, key: const Key('admin_user_error'), style: TextStyle(color: theme.colorScheme.error)),
          ],
        ],
      ),
    );
  }
}

class _RoleRow extends StatelessWidget {
  const _RoleRow({required this.role, required this.value, required this.onChanged, this.lockedReason});

  final RoleInfo role;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? lockedReason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg3 = NomorexTokens.of(context).fg3;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(role.name, style: theme.textTheme.titleSmall),
                Text(lockedReason ?? role.description, style: theme.textTheme.bodySmall?.copyWith(color: fg3)),
              ],
            ),
          ),
          Semantics(
            label: 'Role ${role.name}',
            child: Switch(
              key: Key('admin_role_${role.name}'),
              value: value,
              onChanged: lockedReason != null ? null : onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
