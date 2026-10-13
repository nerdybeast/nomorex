import 'package:flutter/material.dart';
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

    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.content_copy_outlined, size: 12, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
