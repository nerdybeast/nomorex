import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// A bordered panel of guidance text. An eyebrow [title] sits in the
/// upper-left and an info icon in the upper-right.
///
/// [children] are stacked below the header and spaced apart. Plain `Text`
/// children pick up the panel's body style (bodyMedium in `fg2`) through a
/// [DefaultTextStyle], so callers don't need to style them.
class InfoPanel extends StatelessWidget {
  const InfoPanel({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    final bodyStyle =
        Theme.of(context).textTheme.bodyMedium?.copyWith(color: palette.fg2);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.bg1,
        border: Border.all(color: palette.borderSubtle),
        borderRadius: BorderRadius.circular(NomorexSizes.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: tokens.eyebrow)),
              const SizedBox(width: 8),
              Icon(Icons.info_outline, size: 18, color: palette.fg3),
            ],
          ),
          DefaultTextStyle.merge(
            style: bodyStyle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final child in children) ...[
                  const SizedBox(height: 12),
                  child,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
