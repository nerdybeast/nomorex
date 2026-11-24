import 'package:material_ui/material_ui.dart';
import '../../core/theme/app_theme.dart';
import 'archived_pill.dart';
import 'list_group.dart';

/// Shared chrome for a list entry that summarizes a program or workout: a
/// bordered icon tile, a [title] in title-3, an optional [status] line right
/// under it, an optional muted [subtitle] (e.g. the author), an optional
/// [badge] (e.g. a `CopiedFromBadge`), an optional [body] clamped to two
/// lines, and a row of small [chips].
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
    this.leading,
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

  /// Replaces the icon tile with one that carries data, such as a program's
  /// week count (`ProgramWeeksTile`). Ignored on an archived row.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = NomorexTokens.of(context).palette;
    final sub = subtitle;

    final iconTile = Container(
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
    );

    final details = Column(
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
          // title-3: the name is what the row is scanned for, so it
          // leads the 13px body by weight and a size step. Three lines at
          // most, so a long imported name can't fill a phone screen.
          Text(title, style: theme.textTheme.titleMedium, maxLines: 3, overflow: TextOverflow.ellipsis),
        // State (running, paused, upcoming) sits right under the
        // name: it matters more than the description below it.
        if (status != null) ...[const SizedBox(height: 4), status!],
        if (sub != null) ...[
          const SizedBox(height: 2),
          Text(sub, style: theme.textTheme.bodySmall?.copyWith(color: palette.fg3)),
        ],
        if (badge != null) ...[const SizedBox(height: 6), badge!],
        if (body != null) ...[
          const SizedBox(height: 4),
          // Two lines at most, so a long description can't outweigh
          // the name or push the next row off screen.
          DefaultTextStyle.merge(
            style: NomorexTokens.of(context).bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            child: body!,
          ),
        ],
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 4, children: chips),
        ],
      ],
    );

    // An archived row is two short lines; centering it keeps the Restore
    // button level with them rather than pinned to the top.
    final align = archived ? CrossAxisAlignment.center : CrossAxisAlignment.start;

    return GroupableTile(
      onTap: onTap,
      // The row announces itself below, as one button.
      excludeFromSemantics: true,
      child: Row(
        crossAxisAlignment: align,
        children: [
          // One button to a screen reader, named by everything it says
          // (name, state, facts), with the trailing menu or Restore left
          // outside it as its own control: a button inside a button can't
          // be reached on its own.
          Expanded(
            child: MergeSemantics(
              child: Semantics(
                button: true,
                onTap: onTap,
                child: Row(
                  crossAxisAlignment: align,
                  children: [
                    if (archived || leading == null) iconTile else leading!,
                    const SizedBox(width: 12),
                    Expanded(child: details),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          trailing ??
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: ExcludeSemantics(child: Icon(Icons.chevron_right, size: 20, color: palette.fg3)),
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
        // 14, as in the design system's pills, beside 12px text.
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        // Shrinks rather than overflows when a chip alone is wider than a
        // narrow row (a large text size on a small phone).
        Flexible(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// "1 week" / "2 weeks".
String pluralize(int n, String singular) => '$n $singular${n == 1 ? '' : 's'}';

/// "Deadlift · Row · Curl  +2 more" from a list of exercise names.
String exercisePreview(List<String> names, {int max = 3}) {
  final shown = names.take(max).join(' · ');
  final more = names.length - max;
  return more > 0 ? '$shown  +$more more' : shown;
}
