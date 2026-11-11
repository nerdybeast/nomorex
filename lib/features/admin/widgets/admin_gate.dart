import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/app_roles.dart';
import '../providers/current_roles_provider.dart';

/// Shows [child] only to admins. The `/admin` route already redirects
/// everyone else, so this only matters if a role is removed while the screen
/// is open. The server refuses every admin call regardless.
class AdminGate extends ConsumerWidget {
  const AdminGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roles = ref.watch(currentUserRolesProvider);
    // A refresh keeps the previous roles, so an admin doesn't see the screen
    // flicker to "no access" each time they're re-read.
    final value = roles.value;
    if (value != null && value.contains(AppRoles.admin)) return child;
    if (value == null && roles.isLoading) return const Center(child: CircularProgressIndicator());
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          "You don't have access to this page.",
          key: const Key('admin_no_access'),
          textAlign: TextAlign.center,
          style: TextStyle(color: NomorexTokens.of(context).fg2),
        ),
      ),
    );
  }
}
