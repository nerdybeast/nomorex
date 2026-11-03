import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/one_rep_max_formula.dart';
import '../models/personal_best.dart';
import '../utils/progression_points.dart';

/// A lift's progression as a small estimated-1RM line, or — until it has
/// [kMinProgressionPoints] plottable entries — a note saying how many more
/// it needs.
///
/// Decorative, not a full chart: no axes or labels. Points are spaced by date
/// and scaled to the lift's own min/max.
class PrProgression extends StatelessWidget {
  const PrProgression({
    super.key,
    required this.entries,
    required this.formula,
  });

  final List<PersonalBest> entries;
  final OneRepMaxFormula formula;

  @override
  Widget build(BuildContext context) {
    final palette = NomorexTokens.of(context).palette;
    final points = progressionPoints(entries, formula);

    if (points.length < kMinProgressionPoints) {
      return Text(
        'Progression trend line will show after the PR has multiple updates. '
        '${points.length} / $kMinProgressionPoints updates completed!',
        key: const Key('pr_progression_hint'),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: palette.fg3),
      );
    }

    return Semantics(
      label: 'Progression trend, ${points.length} updates',
      child: SizedBox(
        key: const Key('pr_progression_chart'),
        height: 40,
        width: double.infinity,
        child: CustomPaint(
          painter: _SparklinePainter(
            points: points,
            lineColor: palette.primary,
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.points, required this.lineColor});

  final List<ProgressionPoint> points;
  final Color lineColor;

  static const _dotRadius = 2.5;
  static const _latestDotRadius = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    // Inset by the largest dot so nothing is clipped at the edges.
    const inset = _latestDotRadius;
    final width = size.width - inset * 2;
    final height = size.height - inset * 2;
    if (width <= 0 || height <= 0) return;

    final firstMs = points.first.date.millisecondsSinceEpoch;
    final spanMs = points.last.date.millisecondsSinceEpoch - firstMs;
    final values = points.map((p) => p.estimatedOneRepMaxKg);
    final minY = values.reduce((a, b) => a < b ? a : b);
    final rangeY = values.reduce((a, b) => a > b ? a : b) - minY;

    Offset toOffset(int i) {
      final p = points[i];
      // All on one day: fall back to even spacing rather than stacking.
      final xFraction = spanMs == 0
          ? i / (points.length - 1)
          : (p.date.millisecondsSinceEpoch - firstMs) / spanMs;
      // Flat history: draw the line through the middle.
      final yFraction =
          rangeY == 0 ? 0.5 : (p.estimatedOneRepMaxKg - minY) / rangeY;
      return Offset(inset + xFraction * width, inset + (1 - yFraction) * height);
    }

    final offsets = [for (var i = 0; i < points.length; i++) toOffset(i)];

    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (final o in offsets.skip(1)) {
      path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    final dot = Paint()..color = lineColor;
    for (var i = 0; i < offsets.length; i++) {
      final isLatest = i == offsets.length - 1;
      canvas.drawCircle(offsets[i], isLatest ? _latestDotRadius : _dotRadius, dot);
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.lineColor != lineColor || !listEquals(old.points, points);
}
