import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Marks a subtree as sitting inside a [ListGroup], so
/// row widgets ([SummaryCard], [PrCard], the dashboard status cards…) drop
/// their own card chrome and render as plain rows divided by hairlines.
class ListGroupScope extends InheritedWidget {
  const ListGroupScope({super.key, required super.child});

  static bool isGrouped(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ListGroupScope>() != null;

  @override
  bool updateShouldNotify(ListGroupScope oldWidget) => false;
}

/// The surface of one list entry: a bordered card on its own, or a bare row
/// (with a hover/press fill) inside a [ListGroup].
class GroupableTile extends StatelessWidget {
  const GroupableTile({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.color,
    this.margin,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Optional fill, e.g. primary-subtle for today's program day.
  final Color? color;

  /// Margin when rendered as a standalone card; ignored inside a group.
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final palette = NomorexTokens.of(context).palette;
    final content = InkWell(
      onTap: onTap,
      hoverColor: palette.bg3,
      highlightColor: palette.bg3,
      splashColor: Colors.transparent,
      child: Padding(padding: padding, child: child),
    );
    if (ListGroupScope.isGrouped(context)) {
      return Material(color: color ?? Colors.transparent, child: content);
    }
    return Card(
      margin: margin,
      color: color,
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}

/// A header strip for a [ListGroup]: a mono caps eyebrow on bg-0, with an
/// optional trailing widget (a "View all" link, a "2/4 sets" count).
class ListGroupHeader extends StatelessWidget {
  const ListGroupHeader({super.key, required this.title, this.trailing, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    return ColoredBox(
      color: tokens.palette.bg0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title.toUpperCase(), style: tokens.eyebrow),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.fg3),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Related rows in one bordered container, divided by hairlines, instead of
/// a separate card per item. For short, non-scrolling lists (dashboard
/// sections, and the main lists, where a user's item counts stay small).
class ListGroup extends StatelessWidget {
  const ListGroup({super.key, required this.children, this.header, this.margin});

  final List<Widget> children;
  final Widget? header;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final palette = NomorexTokens.of(context).palette;
    // A Material, not a decorated Container: rows like CheckboxListTile paint
    // their ink on the nearest Material, which a colored box would hide.
    final group = Material(
      color: palette.bg1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NomorexSizes.radiusLg),
        side: BorderSide(color: palette.borderSubtle),
      ),
      child: ListGroupScope(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header != null) ...[header!, const Divider()],
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(),
              children[i],
            ],
          ],
        ),
      ),
    );
    final m = margin;
    return m == null ? group : Padding(padding: m, child: group);
  }
}
