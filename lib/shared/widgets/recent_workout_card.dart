import 'package:flutter/material.dart';

/// Card for a completed workout. [completedDisplay] is pre-formatted (e.g.
/// "Completed Aug 11, 2026") so this widget has no dependency on the data
/// layer, matching [WorkoutInProgressCard]'s shape.
class RecentWorkoutCard extends StatelessWidget {
  const RecentWorkoutCard({
    super.key,
    required this.title,
    required this.completedDisplay,
    this.onTap,
  });

  final String title;
  final String completedDisplay;
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
                    Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      completedDisplay,
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
