import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/list_group.dart';

/// One day row in a program's week/day list — shared by the template browse
/// screen and the running-instance screen. [highlighted] gives the current
/// day (in an active instance) a subtle tint and a "TODAY" pill; [showChevron]/[onTap] are only
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
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;

    // Today's day fills with primary-subtle and carries a mono "TODAY" pill
    // outlined in primary-text — no orange border on the row.
    return GroupableTile(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 8),
      color: highlighted ? palette.primarySubtle : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(title, style: theme.textTheme.titleSmall)),
                    if (highlighted) ...[
                      const SizedBox(width: 8),
                      Container(
                        key: const Key('program_day_today_pill'),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          border: Border.all(color: palette.primaryText),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'TODAY',
                          style: tokens.eyebrow.copyWith(color: palette.primaryText),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: highlighted ? palette.fg2 : palette.fg3,
                  ),
                ),
              ],
            ),
          ),
          if (showChevron) Icon(Icons.chevron_right, size: 20, color: palette.fg3),
        ],
      ),
    );
  }
}
