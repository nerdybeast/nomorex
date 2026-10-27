import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'archived_pill.dart';
import 'list_group.dart';

/// Shared chrome for a list entry that summarizes a program or workout: a
/// bordered icon tile, a bold [title], an optional muted [subtitle] (e.g. the author),
/// an optional [badge] (e.g. a `CopiedFromBadge`), an optional [body] and
/// [status] line, and a row of small [chips].
///
/// [trailing] defaults to a chevron; pass a menu button for owner-editable
/// lists.
///
/// [archived] renders the design system's archived state: an `archive` icon
/// in fg-3 instead of [icon], the title dropped to fg-2 and followed by an
/// [ArchivedPill], and [trailing] centered (callers pass `ArchivedRowActions`
/// and an `Archived <date>` chip). No orange anywhere on the row.
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.badge,
    this.body,
    this.status,
    this.chips = const [],
    this.trailing,
    this.archived = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? subtitle;
  final Widget? badge;
  final Widget? body;
  final Widget? status;
  final List<SummaryInfoChip> chips;
  final Widget? trailing;
  final bool archived;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = NomorexTokens.of(context).palette;
    final sub = subtitle;

    return GroupableTile(
      onTap: onTap,
      child: Row(
        // An archived row is two short lines; centering it keeps the Restore
        // button level with them rather than pinned to the top.
        crossAxisAlignment: archived ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          // Neutral icon tile: bordered, bg-2, fg-2 icon — no orange here.
          Container(
            width: NomorexSizes.iconTileSize,
            height: NomorexSizes.iconTileSize,
            decoration: BoxDecoration(
              color: palette.bg2,
              border: Border.all(color: palette.borderDefault),
              borderRadius: BorderRadius.circular(NomorexSizes.radiusMd),
            ),
            child: archived
                ? Icon(Icons.archive_outlined, color: palette.fg3, size: 18)
                : Icon(icon, color: palette.fg2, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (archived)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(title, style: theme.textTheme.titleSmall?.copyWith(color: palette.fg2)),
                      const ArchivedPill(),
                    ],
                  )
                else
                  Text(title, style: theme.textTheme.titleSmall),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(sub, style: theme.textTheme.bodySmall?.copyWith(color: palette.fg3)),
                ],
                if (badge != null) ...[const SizedBox(height: 6), badge!],
                if (body != null) ...[
                  const SizedBox(height: 4),
                  DefaultTextStyle.merge(
                    style: TextStyle(fontSize: 13, height: 18 / 13, color: palette.fg2),
                    child: body!,
                  ),
                ],
                if (status != null) ...[const SizedBox(height: 6), status!],
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 12, runSpacing: 4, children: chips),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing ??
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Icon(Icons.chevron_right, size: 20, color: palette.fg3),
              ),
        ],
      ),
    );
  }
}

/// A small icon + label fact shown under a [SummaryCard]'s body.
class SummaryInfoChip extends StatelessWidget {
  const SummaryInfoChip(this.icon, this.label, {super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = NomorexTokens.of(context).fg3;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: color)),
      ],
    );
  }
}

/// "1 week" / "2 weeks".
String pluralize(int n, String singular) => '$n $singular${n == 1 ? '' : 's'}';

/// Rest days are part of a program's schedule but not a session anyone trains,
/// so this is the number that says how much work a program is.
int countTrainingDays(Iterable<Iterable<bool>> restFlagsByWeek) =>
    restFlagsByWeek.expand((w) => w).where((isRest) => !isRest).length;

/// "Deadlift · Row · Curl  +2 more" from a list of exercise names.
String exercisePreview(List<String> names, {int max = 3}) {
  final shown = names.take(max).join(' · ');
  final more = names.length - max;
  return more > 0 ? '$shown  +$more more' : shown;
}
