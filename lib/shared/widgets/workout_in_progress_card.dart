import 'package:flutter/material.dart';

/// Dashboard card for one in-progress (or paused) workout. [statusDisplay]
/// is pre-formatted (e.g. "In progress — started 2:45 PM" or "Paused —
/// started 2:45 PM") so this widget has no dependency on the data layer,
/// matching [ProgramInstanceCard]'s shape.
class WorkoutInProgressCard extends StatelessWidget {
  const WorkoutInProgressCard({
    super.key,
    required this.title,
    required this.statusDisplay,
    this.onTap,
  });

  final String title;
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                statusDisplay,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
