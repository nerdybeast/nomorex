import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// The mono caps "ARCHIVED" marker after an archived record's title: a
/// border-default outline with fg-3 text and no fill, so it never reads as
/// an action.
class ArchivedPill extends StatelessWidget {
  const ArchivedPill({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    return Container(
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        border: Border.all(color: tokens.palette.borderDefault),
        borderRadius: BorderRadius.circular(999),
      ),
      // A min-size Row centers the label vertically without the Container
      // stretching to the full width it's offered (as `alignment` would).
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Text('ARCHIVED', style: tokens.eyebrow.copyWith(height: 1))],
      ),
    );
  }
}
