import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/admin_user.dart';

/// "26–50 of 132" with previous/next buttons, under a paginated admin list.
/// The buttons have tooltips, so screen readers and role locators can find them.
class AdminPageControls extends StatelessWidget {
  const AdminPageControls({super.key, required this.page, required this.onPage});

  final AdminPage<Object?> page;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    // A page past the end (rows removed since the last one loaded) has no
    // rows and so no total; Previous still leads back.
    final label = page.items.isEmpty
        ? 'No results'
        : '${page.firstIndex + 1}–${page.firstIndex + page.items.length} of ${page.total}';
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          label,
          key: const Key('admin_page_range'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: NomorexTokens.of(context).fg2),
        ),
        const SizedBox(width: 8),
        IconButton(
          key: const Key('admin_page_previous'),
          tooltip: 'Previous page',
          icon: const Icon(Icons.chevron_left),
          onPressed: page.hasPrevious ? () => onPage(page.page - 1) : null,
        ),
        IconButton(
          key: const Key('admin_page_next'),
          tooltip: 'Next page',
          icon: const Icon(Icons.chevron_right),
          onPressed: page.hasNext ? () => onPage(page.page + 1) : null,
        ),
      ],
    );
  }
}
