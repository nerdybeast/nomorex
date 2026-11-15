import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// "Archived" beside a list's search field, on Training's Programs and
/// Workouts views. On, the list shows the archived items instead of the active
/// ones. It replaces a full Active/Archived tab bar, which stacked a second row
/// of tabs under Training's switcher.
///
/// Announced as a toggle button named "Archived" with its count, so a screen
/// reader hears both what it does and whether it's on.
class ArchivedToggle extends StatelessWidget {
  const ArchivedToggle({super.key, required this.selected, required this.count, required this.onChanged});

  final bool selected;

  /// How many archived items there are; null while loading.
  final int? count;

  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    final fg = selected ? palette.primaryText : palette.fg2;
    final n = count;
    return Semantics(
      button: true,
      toggled: selected,
      label: 'Archived',
      value: n == null ? null : '$n',
      excludeSemantics: true,
      onTap: () => onChanged(!selected),
      child: Material(
        color: selected ? palette.primarySubtle : palette.bg2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NomorexSizes.radiusMd),
          side: BorderSide(color: selected ? palette.primaryBorder : palette.borderDefault),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onChanged(!selected),
          focusColor: palette.bg3,
          child: ConstrainedBox(
            // A 48px hit area, like every other control.
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.archive_outlined, size: 18, color: fg),
                  const SizedBox(width: 6),
                  Text('Archived', style: tokens.buttonSmall.copyWith(color: fg)),
                  if (n != null) ...[
                    const SizedBox(width: 6),
                    Text('$n', style: tokens.eyebrow.copyWith(color: selected ? fg : palette.fg3)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
