import 'package:material_ui/material_ui.dart';
import '../../core/theme/app_theme.dart';
import 'list_group.dart';

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
    this.isLive = true,
    this.programLabel,
    this.isStandalone = false,
    this.onTap,
  });

  final String title;
  final String statusDisplay;
  final Widget? statusTrailing;

  /// Running (true) or paused (false): drives the status dot, which is the
  /// only orange on the row while a workout is live.
  final bool isLive;

  /// Which program the workout belongs to, shown under the title; null hides
  /// the line. When [isStandalone] it reads "Standalone" instead, dimmer.
  final String? programLabel;
  final bool isStandalone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = NomorexTokens.of(context).palette;
    final statusStyle = theme.textTheme.bodySmall?.copyWith(color: palette.fg3);
    return GroupableTile(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            key: const Key('workout_status_dot'),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isLive ? palette.primary : palette.fg3,
              boxShadow: isLive
                  ? [BoxShadow(color: palette.primarySubtle, spreadRadius: 3)]
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                if (programLabel != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    key: const Key('workout_program_label'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isStandalone ? Icons.fitness_center : Icons.checklist_outlined,
                        size: 14,
                        color: isStandalone ? palette.fg3 : palette.fg2,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          programLabel!,
                          style: statusStyle?.copyWith(
                            color: isStandalone ? palette.fg3 : palette.fg2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 2),
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
                      DefaultTextStyle.merge(
                        style: TextStyle(
                          color: palette.fg1,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        child: statusTrailing!,
                      ),
                    ],
                  ],
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
