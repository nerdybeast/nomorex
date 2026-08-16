import 'package:flutter/material.dart';

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
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(programName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      statusDisplay,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
