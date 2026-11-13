import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/list_group.dart';
import '../models/admin_section.dart';
import '../providers/current_roles_provider.dart';
import '../widgets/admin_gate.dart';
import '../../../shared/widgets/responsive_layout.dart';

/// The admin hub, reached from Profile: one row per [kAdminSections] entry the
/// user's roles allow.
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roles = ref.watch(currentUserRolesProvider).value ?? const {};
    final sections = [
      for (final section in kAdminSections)
        if (roles.contains(section.requiredRole)) section,
    ];

    return Scaffold(
      appBar: AppBar(
        // The sidebar is the way back on wide layouts.
        automaticallyImplyLeading: showsBackForSidebarDestination(context),
        title: const Text('Admin'),
      ),
      body: AdminGate(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ListGroup(
                  children: [for (final section in sections) _SectionTile(section: section)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({required this.section});

  final AdminSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = NomorexTokens.of(context);
    return Semantics(
      button: true,
      child: GroupableTile(
        key: Key('admin_section_${section.route}'),
        onTap: () => context.push(section.route),
        child: Row(
          children: [
            Icon(section.icon, color: tokens.fg2),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(section.title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(section.subtitle, style: theme.textTheme.bodySmall?.copyWith(color: tokens.fg3)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: tokens.fg3),
          ],
        ),
      ),
    );
  }
}
