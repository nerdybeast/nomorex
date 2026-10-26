import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// How [DashboardEmptyStateCard] renders its action.
enum EmptyStateCtaStyle {
  /// An orange text link with no box — the Dashboard's sections.
  link,

  /// A small secondary button — a tab's whole-screen empty state.
  button,
}

/// Replaces a bare "no data yet" line on the Dashboard with a small card:
/// an icon, a [title], and a supporting [message]. [ctaLabel]/[onCta] are a
/// matched pair — pass both to show a single subtle action (e.g. "Log your
/// first PR"), or leave both null for a section with no obvious single
/// action to surface here. [ctaStyle] picks a text link or a button.
///
/// The dashed edge sets it apart from cards that hold real data.
class DashboardEmptyStateCard extends StatelessWidget {
  const DashboardEmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.ctaLabel,
    this.onCta,
    this.ctaStyle = EmptyStateCtaStyle.button,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? ctaLabel;
  final VoidCallback? onCta;
  final EmptyStateCtaStyle ctaStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = NomorexTokens.of(context).palette;
    final label = ctaLabel;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: palette.bg1,
        borderRadius: BorderRadius.circular(NomorexSizes.radiusLg),
      ),
      child: CustomPaint(
        foregroundPainter: _DashedBorderPainter(
          color: palette.borderDefault,
          radius: NomorexSizes.radiusLg,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
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
                switch (ctaStyle) {
                  EmptyStateCtaStyle.link => TextButton(
                      onPressed: onCta,
                      style: TextButton.styleFrom(
                        foregroundColor: palette.primaryText,
                        minimumSize: const Size(0, NomorexSizes.controlHeightSm),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        textStyle: theme.textTheme.labelLarge?.copyWith(fontSize: 13),
                      ).copyWith(overlayColor: const WidgetStatePropertyAll(Colors.transparent)),
                      child: Text(label),
                    ),
                  EmptyStateCtaStyle.button => OutlinedButton(
                      onPressed: onCta,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, NomorexSizes.controlHeightSm),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        textStyle: theme.textTheme.labelLarge?.copyWith(fontSize: 13),
                      ),
                      child: Text(label),
                    ),
                },
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A 1px dashed rounded-rect outline — Flutter's [Border] has no dashed
/// style. Dashes of 3px with 3px gaps, like a browser's `border-style: dashed`.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const _dash = 3.0;
  static const _gap = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    // Inset by half the stroke so the line sits fully inside the card.
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(0.5),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += _dash + _gap) {
        canvas.drawPath(metric.extractPath(d, d + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
