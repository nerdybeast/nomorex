import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import 'app_roles.dart';

/// One entry on the admin hub. A new admin feature is one entry here plus a
/// child route under [AppConstants.routeAdmin] in `app.dart`. [requiredRole]
/// lets a future role see only its own sections.
class AdminSection {
  const AdminSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    this.requiredRole = AppRoles.admin,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final String requiredRole;
}

const kAdminSections = [
  AdminSection(
    title: 'Users',
    subtitle: 'See every account and manage their roles',
    icon: Icons.group_outlined,
    route: AppConstants.routeAdminUsers,
  ),
  AdminSection(
    title: 'AI imports',
    subtitle: 'Turn importing from photos and PDFs on or off for everyone',
    icon: Icons.document_scanner_outlined,
    route: AppConstants.routeAdminAiImports,
  ),
  AdminSection(
    title: 'Audit log',
    subtitle: 'Every change made from the Admin area',
    icon: Icons.history,
    route: AppConstants.routeAdminAuditLog,
  ),
];
