import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'list_group.dart';

/// Dashboard card for one running (or upcoming) program instance.
/// [statusDisplay] is pre-formatted (e.g. "Upcoming — starts Aug 12, 2026"
/// or "In progress — started Aug 5, 2026") so this widget has no dependency
/// on the data layer, matching [PrCard]'s shape.
class ProgramInstanceCard extends StatelessWidget {
  const ProgramInstanceCard({
    super.key,
    required this.programName,
    required this.statusDisplay,
    this.onTap,
  });

  final String programName;
  final String statusDisplay;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = NomorexTokens.of(context).palette;
    return GroupableTile(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(programName, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  statusDisplay,
                  style: theme.textTheme.bodySmall?.copyWith(color: palette.fg3),
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 20, color: palette.fg3),
          ],
        ],
      ),
    );
  }
}
