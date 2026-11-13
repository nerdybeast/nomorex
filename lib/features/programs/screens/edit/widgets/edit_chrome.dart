import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';

/// An app bar title with the level above in small type over it:
/// "ZT Strong Like Bull" over "Week 1 · Meso 1/4".
class StackedTitle extends StatelessWidget {
  const StackedTitle({super.key, required this.crumb, required this.title});

  final String crumb;
  final String title;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(crumb, maxLines: 1, overflow: TextOverflow.ellipsis, style: tokens.bodySmall.copyWith(color: tokens.fg3, fontSize: 12, height: 16 / 12)),
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

/// One entry in a [SelectorStrip].
class StripItem {
  const StripItem({required this.key, required this.label, required this.semanticLabel, this.detail});

  final String key;
  final String label;

  /// A second, smaller line ("6 ex").
  final String? detail;

  /// What a screen reader says ("Week 2", "Day 3, 6 exercises").
  final String semanticLabel;
}

/// The row of weeks (W1 W2 …) or days (Day 1 …) under an editor's app bar,
/// for moving sideways without going back up a level. The selected entry is
/// scrolled into view, and [onAdd] puts a + at the end.
class SelectorStrip extends StatefulWidget implements PreferredSizeWidget {
  const SelectorStrip({
    super.key,
    required this.items,
    required this.selectedKey,
    required this.onSelect,
    required this.addTooltip,
    this.onAdd,
    this.semanticLabel,
  });

  final List<StripItem> items;
  final String selectedKey;
  final ValueChanged<String> onSelect;
  final VoidCallback? onAdd;
  final String addTooltip;
  final String? semanticLabel;

  @override
  Size get preferredSize => const Size.fromHeight(57);

  @override
  State<SelectorStrip> createState() => _SelectorStripState();
}

class _SelectorStripState extends State<SelectorStrip> {
  final _selectedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _revealSelected();
  }

  @override
  void didUpdateWidget(SelectorStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedKey != widget.selectedKey) _revealSelected();
  }

  void _revealSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _selectedKey.currentContext;
      if (ctx != null && ctx.mounted) Scrollable.ensureVisible(ctx, alignment: 0.5, duration: const Duration(milliseconds: 150));
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    return Semantics(
      container: true,
      label: widget.semanticLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: palette.borderSubtle))),
        child: SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              for (final item in widget.items)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _StripButton(
                    key: item.key == widget.selectedKey ? _selectedKey : ValueKey('strip_${item.key}'),
                    item: item,
                    selected: item.key == widget.selectedKey,
                    onTap: () => widget.onSelect(item.key),
                  ),
                ),
              if (widget.onAdd != null)
                IconButton(
                  tooltip: widget.addTooltip,
                  onPressed: widget.onAdd,
                  icon: const Icon(Icons.add),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StripButton extends StatelessWidget {
  const _StripButton({super.key, required this.item, required this.selected, required this.onTap});

  final StripItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: item.semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: selected ? palette.bg3 : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NomorexSizes.radiusMd),
          side: BorderSide(color: selected ? palette.borderControl : palette.borderDefault),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(NomorexSizes.radiusMd),
          hoverColor: palette.bg3,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: item.detail == null ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: theme.textTheme.labelLarge?.copyWith(color: selected ? palette.fg1 : tokens.fg2),
                  ),
                  if (item.detail != null)
                    Text(item.detail!, style: tokens.bodySmall.copyWith(fontSize: 11, height: 14 / 11, color: tokens.fg3)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A row of a [showActionSheet].
class SheetAction<T> {
  const SheetAction(this.value, this.label, this.icon, {this.danger = false});

  final T value;
  final String label;
  final IconData icon;
  final bool danger;
}

/// A bottom sheet of actions under a title, the editor's ⋯ menu. Returns the
/// chosen action's value, or null when dismissed.
Future<T?> showActionSheet<T>(
  BuildContext context, {
  required String title,
  required List<SheetAction<T>> actions,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) {
      final tokens = NomorexTokens.of(ctx);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
            ),
            for (final a in actions)
              ListTile(
                key: ValueKey('action_${a.label}'),
                leading: Icon(a.icon, color: a.danger ? tokens.palette.dangerText : tokens.fg2),
                title: Text(a.label, style: a.danger ? TextStyle(color: tokens.palette.dangerText) : null),
                onTap: () => Navigator.pop(ctx, a.value),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

/// Asks for a new name. Returns the trimmed text, or null when cancelled.
/// An empty result is returned as '' so callers can clear an optional label.
Future<String?> showRenameDialog(
  BuildContext context, {
  required String title,
  required String label,
  String? initial,
  String? hint,
}) async {
  final controller = TextEditingController(text: initial ?? '');
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: label, hintText: hint),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Save')),
      ],
    ),
  );
  controller.dispose();
  return result;
}

/// Shown on a week or day link whose target was deleted, e.g. from another
/// device: says so and offers the way back up.
class GoneState extends StatelessWidget {
  const GoneState({super.key, required this.message, required this.actionLabel, required this.onAction});

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            FilledButton(
              style: NomorexTokens.of(context).secondaryButtonStyle,
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

/// A short message at the bottom of the screen.
void showEditSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
