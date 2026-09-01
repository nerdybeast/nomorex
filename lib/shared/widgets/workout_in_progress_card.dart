import 'package:flutter/material.dart';

/// Dashboard card for one in-progress (or paused) workout. [statusDisplay] is
/// pre-formatted (e.g. "In progress" or "Paused") and [statusTrailing] is an
/// arbitrary widget appended after a separator — the elapsed-time ticker, in
/// practice — so this widget keeps no dependency on the data layer or on the
/// workouts feature, matching [ProgramInstanceCard]'s shape.
class WorkoutInProgressCard extends StatelessWidget {
  const WorkoutInProgressCard({
    super.key,
    required this.title,
    required this.statusDisplay,
    this.statusTrailing,
    this.onTap,
  });

  final String title;
  final String statusDisplay;
  final Widget? statusTrailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusStyle =
        theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Flexible + ellipsis so a long status can't overflow
                        // the row and shove the chevron off a narrow phone.
                        Flexible(
                          child: Text(
                            statusDisplay,
                            style: statusStyle,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (statusTrailing != null) ...[
                          Text(' · ', style: statusStyle),
                          statusTrailing!,
                        ],
                      ],
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
