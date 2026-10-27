import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Trailing actions for an archived [SummaryCard] row: a visible small
/// "Restore" button — restoring is the main action on an archived record, so
/// it isn't hidden in a menu — and, for records that can be hard-deleted, a
/// `more_horiz` menu holding a single destructive "Delete permanently".
class ArchivedRowActions extends StatelessWidget {
  const ArchivedRowActions({super.key, required this.onRestore, this.onDelete});

  final VoidCallback onRestore;

  /// Null for records that are never hard-deleted (programs): no menu then.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    final delete = onDelete;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton(
          key: const Key('archived_restore'),
          style: tokens.secondaryButtonStyle.copyWith(
            minimumSize: const WidgetStatePropertyAll(Size(0, NomorexSizes.controlHeightSm)),
            padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
            textStyle: WidgetStatePropertyAll(
              Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 13),
            ),
          ),
          onPressed: onRestore,
          child: const Text('Restore'),
        ),
        if (delete != null)
          PopupMenuButton<String>(
            key: const Key('archived_menu'),
            icon: const Icon(Icons.more_horiz),
            onSelected: (_) => delete(),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18, color: tokens.palette.dangerText),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Delete permanently',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: tokens.palette.dangerText),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}
