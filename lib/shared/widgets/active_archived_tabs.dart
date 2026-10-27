import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// The "Active" / "Archived" tabs under the app bar of a list that can hold
/// archived records (Programs, Workouts). Each tab carries its count, so the
/// user can see whether anything is archived before switching. A count that
/// hasn't loaded yet shows no pill rather than a misleading zero.
class ActiveArchivedTabs extends StatelessWidget implements PreferredSizeWidget {
  const ActiveArchivedTabs({super.key, this.activeCount, this.archivedCount});

  final int? activeCount;
  final int? archivedCount;

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  Widget build(BuildContext context) {
    return TabBar(
      tabs: [
        _CountTab(key: const Key('tab_active'), label: 'Active', count: activeCount),
        _CountTab(key: const Key('tab_archived'), label: 'Archived', count: archivedCount),
      ],
    );
  }
}

class _CountTab extends StatelessWidget {
  const _CountTab({super.key, required this.label, required this.count});

  final String label;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    final n = count;
    return Tab(
      height: 44,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (n != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: tokens.palette.bg3,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('$n', style: tokens.eyebrow.copyWith(color: tokens.fg2)),
            ),
          ],
        ],
      ),
    );
  }
}
