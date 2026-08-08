import 'package:flutter/material.dart';

/// One day row in a program's week/day list — shared by the template browse
/// screen and the running-instance screen. [highlighted] gives the current
/// day (in an active instance) a subtle tint; [showChevron]/[onTap] are only
/// set when the day actually has something to navigate into.
class ProgramDayCard extends StatelessWidget {
  const ProgramDayCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.showChevron = false,
    this.highlighted = false,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final bool showChevron;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: highlighted ? colorScheme.primaryContainer : null,
      shape: highlighted
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: colorScheme.primary),
            )
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (showChevron)
                Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
