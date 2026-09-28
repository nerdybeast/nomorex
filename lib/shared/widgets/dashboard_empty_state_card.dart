import 'package:flutter/material.dart';

/// Replaces a bare "no data yet" line on the Dashboard with a small card:
/// an icon, a [title], and a supporting [message]. [ctaLabel]/[onCta] are a
/// matched pair — pass both to show a single subtle action (e.g. "Log your
/// first PR"), or leave both null for a section with no obvious single
/// action to surface here.
class DashboardEmptyStateCard extends StatelessWidget {
  const DashboardEmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.ctaLabel,
    this.onCta,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? ctaLabel;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = ctaLabel;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (label != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onCta, child: Text(label)),
            ],
          ],
        ),
      ),
    );
  }
}
