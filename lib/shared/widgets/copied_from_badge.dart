import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/copy_attribution.dart';

/// "Copied from …" pill for a workout or program the user saved from
/// Community (or derived from such a copy). Renders nothing for content the
/// user created themselves, so it can be dropped unconditionally into any
/// card or header.
class CopiedFromBadge extends StatelessWidget {
  const CopiedFromBadge({
    super.key = const Key('copied_from_badge'),
    required this.isCopy,
    this.copiedFromUserId,
    this.copiedFromDisplayName,
    this.copiedFromSourceId,
  });

  final bool isCopy;
  final String? copiedFromUserId;
  final String? copiedFromDisplayName;
  final String? copiedFromSourceId;

  @override
  Widget build(BuildContext context) {
    final label = copyAttributionLabel(
      isCopy: isCopy,
      copiedFromUserId: copiedFromUserId,
      copiedFromDisplayName: copiedFromDisplayName,
      copiedFromSourceId: copiedFromSourceId,
    );
    if (label == null) return const SizedBox.shrink();

    final palette = NomorexTokens.of(context).palette;
    // Outlined, unfilled pill: border-default edge, fg-2 icon and label.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: palette.borderDefault),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.content_copy_outlined, size: 14, color: palette.fg2),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, height: 16 / 12, color: palette.fg2),
            ),
          ),
        ],
      ),
    );
  }
}
