import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'list_group.dart';

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
    final palette = NomorexTokens.of(context).palette;
    return GroupableTile(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  completedDisplay,
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
