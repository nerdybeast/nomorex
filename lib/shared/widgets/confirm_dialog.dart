import 'package:flutter/material.dart';
import '../../core/theme/dark_theme.dart';

/// "Are you sure" confirmation for a destructive action, matching the style
/// of FinishWorkoutScreen's "Discard workout?" dialog. Returns true only if
/// the user tapped the confirm button.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
}) async {
  final tokens = Theme.of(context).extension<NomorexDarkTokens>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      // Buttons live in `content`, not `actions`: OverflowBar (actions'
      // layout) does a dry intrinsic-size pass that breaks the Expanded
      // pair below.
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: tokens?.secondaryButtonStyle,
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(cancelLabel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: tokens?.dangerButtonStyle,
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(confirmLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return confirmed ?? false;
}
