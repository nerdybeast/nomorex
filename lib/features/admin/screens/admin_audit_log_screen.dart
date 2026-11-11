import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/list_group.dart';
import '../providers/admin_users_provider.dart';
import '../utils/audit_entry_text.dart';
import '../widgets/admin_gate.dart';
import '../widgets/admin_page_controls.dart';

/// Every admin action, newest first.
class AdminAuditLogScreen extends ConsumerStatefulWidget {
  const AdminAuditLogScreen({super.key});

  @override
  ConsumerState<AdminAuditLogScreen> createState() => _AdminAuditLogScreenState();
}

class _AdminAuditLogScreenState extends ConsumerState<AdminAuditLogScreen> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final provider = adminAuditLogProvider(page: _page);
    final result = ref.watch(provider);
    final theme = Theme.of(context);
    final tokens = NomorexTokens.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Audit log')),
      body: AdminGate(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: switch (result) {
                  AsyncValue(:final value?) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (value.items.isEmpty && value.page == 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              'No admin actions yet.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: tokens.fg2),
                            ),
                          )
                        else
                          ListGroup(
                            children: [
                              for (final entry in value.items)
                                GroupableTile(
                                  key: ValueKey('admin_audit_${entry.id}'),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(describeAuditEntry(entry), style: theme.textTheme.bodyMedium),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${formatDate(entry.createdAt.toLocal())}, ${formatTime(entry.createdAt)}',
                                        style: theme.textTheme.bodySmall?.copyWith(color: tokens.fg3),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        const SizedBox(height: 8),
                        AdminPageControls(page: value, onPage: (page) => setState(() => _page = page)),
                      ],
                    ),
                  AsyncError() => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text("Couldn't load the audit log.", style: TextStyle(color: theme.colorScheme.error)),
                        const SizedBox(height: 12),
                        FilledButton(
                          style: tokens.secondaryButtonStyle,
                          onPressed: () => ref.invalidate(provider),
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  _ => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
