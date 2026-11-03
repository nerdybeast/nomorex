import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/one_rep_max_formula.dart';
import '../models/personal_best.dart';
import '../utils/progression_axis.dart';
import '../utils/progression_points.dart';

/// A lift's progression as a small estimated-1RM line chart, or — until it
/// has [kMinProgressionPoints] plottable entries — a note saying how many
/// more it needs.
///
/// Points are spaced by date and scaled to the lift's own min/max. The y-axis
/// labels that min, max and the midpoint between them in the user's
/// [unitPreference]; for 'both', lbs
/// go on the left axis and kg on the right. The x-axis labels years or
/// months (see [progressionXTicks]).
class PrProgression extends StatelessWidget {
  const PrProgression({
    super.key,
    required this.entries,
    required this.formula,
    required this.unitPreference,
  });

  final List<PersonalBest> entries;
  final OneRepMaxFormula formula;
  final String unitPreference;

  static const chartHeight = 104.0;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    final points = progressionPoints(entries, formula);

    if (points.length < kMinProgressionPoints) {
      return Text(
        'Progression trend line will show after the PR has multiple updates. '
        '${points.length} / $kMinProgressionPoints updates completed!',
        key: const Key('pr_progression_hint'),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: palette.fg3),
      );
    }

    final values = points.map((p) => p.estimatedOneRepMaxKg);
    final minKg = values.reduce((a, b) => a < b ? a : b);
    final maxKg = values.reduce((a, b) => a > b ? a : b);
    final leftUnit = unitPreference == 'kg' ? 'kg' : 'lbs';
    final rightUnit = unitPreference == 'both' ? 'kg' : null;

    return Semantics(
      label: 'Progression trend, ${points.length} updates, from '
          '${formatAxisWeight(points.first.estimatedOneRepMaxKg, leftUnit)} to '
          '${formatAxisWeight(points.last.estimatedOneRepMaxKg, leftUnit)}',
      excludeSemantics: true,
      child: SizedBox(
        key: const Key('pr_progression_chart'),
        height: chartHeight,
        width: double.infinity,
        child: CustomPaint(
          painter: _ProgressionChartPainter(
            points: points,
            minKg: minKg,
            maxKg: maxKg,
            leftUnit: leftUnit,
            rightUnit: rightUnit,
            xTicks: progressionXTicks(points.first.date, points.last.date),
            lineColor: palette.primary,
            gridColor: palette.borderSubtle,
            labelStyle: tokens.weight.copyWith(
              fontSize: 10,
              height: 1.2,
              color: palette.fg3,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressionChartPainter extends CustomPainter {
  _ProgressionChartPainter({
    required this.points,
    required this.minKg,
    required this.maxKg,
    required this.leftUnit,
    required this.rightUnit,
    required this.xTicks,
    required this.lineColor,
    required this.gridColor,
    required this.labelStyle,
  });

  final List<ProgressionPoint> points;
  final double minKg;
  final double maxKg;
  final String leftUnit;
  final String? rightUnit;
  final List<AxisTick> xTicks;
  final Color lineColor;
  final Color gridColor;
  final TextStyle labelStyle;

  static const _dotRadius = 2.5;
  static const _latestDotRadius = 4.0;
  static const _axisGap = 6.0;

  TextPainter _label(String text) => TextPainter(
        text: TextSpan(text: text, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final flat = maxKg == minKg;

    // Y labels top to bottom: max, midpoint, min — three gridlines so the
    // middle of the chart has a reference too. Just one, centred, when every
    // point is the same weight.
    final midKg = (minKg + maxKg) / 2;
    List<TextPainter> yLabels(String unit) => [
          _label(formatAxisWeight(maxKg, unit)),
          if (!flat) ...[
            _label(formatAxisWeight(midKg, unit)),
            _label(formatAxisWeight(minKg, unit)),
          ],
        ];
    final left = yLabels(leftUnit);
    final right = rightUnit == null ? const <TextPainter>[] : yLabels(rightUnit!);
    double widest(List<TextPainter> ls) =>
        ls.fold(0, (w, l) => l.width > w ? l.width : w);

    final xLabelHeight = _label('0').height;
    final plot = Rect.fromLTRB(
      widest(left) + _axisGap + _latestDotRadius,
      _latestDotRadius + xLabelHeight / 2,
      size.width - (right.isEmpty ? 0 : widest(right) + _axisGap) - _latestDotRadius,
      size.height - xLabelHeight - _axisGap - _latestDotRadius,
    );
    if (plot.width <= 0 || plot.height <= 0) return;

    final firstMs = points.first.date.millisecondsSinceEpoch;
    final spanMs = points.last.date.millisecondsSinceEpoch - firstMs;
    double xForDate(DateTime d) => spanMs == 0
        ? plot.center.dx
        : plot.left + (d.millisecondsSinceEpoch - firstMs) / spanMs * plot.width;
    double yForKg(double kg) =>
        flat ? plot.center.dy : plot.bottom - (kg - minKg) / (maxKg - minKg) * plot.height;

    // Gridlines at the labelled weights.
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final gridYs = flat ? [plot.center.dy] : [plot.top, plot.center.dy, plot.bottom];
    for (final y in gridYs) {
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
    }

    // Y-axis labels, vertically centred on their gridlines.
    for (var i = 0; i < left.length; i++) {
      final l = left[i];
      l.paint(canvas, Offset(0, gridYs[i] - l.height / 2));
    }
    for (var i = 0; i < right.length; i++) {
      final l = right[i];
      l.paint(canvas, Offset(size.width - l.width, gridYs[i] - l.height / 2));
    }

    // X-axis labels, centred under their date but kept inside the plot's
    // horizontal extent so an edge tick doesn't run off the card.
    final xLabelTop = size.height - xLabelHeight;
    for (final tick in xTicks) {
      final l = _label(tick.label);
      final x = (xForDate(tick.date) - l.width / 2)
          .clamp(plot.left - _latestDotRadius, plot.right + _latestDotRadius - l.width);
      l.paint(canvas, Offset(x, xLabelTop));
    }

    // The line and its points.
    final offsets = [
      for (var i = 0; i < points.length; i++)
        Offset(
          // Several entries on one day: spread evenly rather than stacking.
          spanMs == 0
              ? plot.left + i / (points.length - 1) * plot.width
              : xForDate(points[i].date),
          yForKg(points[i].estimatedOneRepMaxKg),
        ),
    ];
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
  bool shouldRepaint(_ProgressionChartPainter old) =>
      old.leftUnit != leftUnit ||
      old.rightUnit != rightUnit ||
      old.lineColor != lineColor ||
      old.gridColor != gridColor ||
      old.labelStyle != labelStyle ||
      !listEquals(old.points, points) ||
      !listEquals(old.xTicks, xTicks);
}
