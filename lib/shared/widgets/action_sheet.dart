import 'package:material_ui/material_ui.dart';
import '../../core/theme/app_theme.dart';

/// One entry in [showActionSheet]: a value, its label and icon, and whether
/// it's destructive (drawn in `danger-text`).
class SheetAction<T> {
  const SheetAction(this.value, this.label, this.icon, {this.danger = false, this.dividerBefore = false});

  final T value;
  final String label;
  final IconData icon;
  final bool danger;

  /// Starts a new group of actions with a hairline above it, so a long menu
  /// reads in sections and the destructive action stands apart.
  final bool dividerBefore;
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
    // Sized to its actions, and scrolls when they outgrow the screen: a long
    // menu (a set group's has up to seven entries) would otherwise overflow
    // the default 9/16-height sheet.
    isScrollControlled: true,
    builder: (ctx) {
      final tokens = NomorexTokens.of(ctx);
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
              ),
              for (final a in actions) ...[
                if (a.dividerBefore) Divider(height: 1, color: tokens.palette.borderSubtle),
                ListTile(
                  key: ValueKey('action_${a.label}'),
                  leading: Icon(a.icon, color: a.danger ? tokens.palette.dangerText : tokens.fg2),
                  title: Text(a.label, style: a.danger ? TextStyle(color: tokens.palette.dangerText) : null),
                  onTap: () => Navigator.pop(ctx, a.value),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}
