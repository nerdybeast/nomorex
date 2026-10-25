import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

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
    final palette = NomorexTokens.of(context).palette;
    final label = ctaLabel;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      decoration: BoxDecoration(
        color: palette.bg1,
        border: Border.all(color: palette.borderDefault),
        borderRadius: BorderRadius.circular(NomorexSizes.radiusLg),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: palette.bg2,
              border: Border.all(color: palette.borderDefault),
              borderRadius: BorderRadius.circular(NomorexSizes.radiusLg),
            ),
            child: Icon(icon, size: 20, color: palette.fg2),
          ),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 13, height: 18 / 13, color: palette.fg2),
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onCta,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, NomorexSizes.controlHeightSm),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                textStyle: theme.textTheme.labelLarge?.copyWith(fontSize: 13),
              ),
              child: Text(label),
            ),
          ],
        ],
      ),
    );
  }
}
