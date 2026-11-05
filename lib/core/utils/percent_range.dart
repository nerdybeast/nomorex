/// Label for a set's %1RM target: "70%", "72.5%", "67–72.5%", or "?%" when
/// none was set. Up to one decimal, trimmed, so a half-percent prescription
/// isn't rounded into a different number ("72.5", not "73").
///
/// [percentageMax] is the top of a range; null or equal means one percentage.
String formatPercentTarget(double? percentage, double? percentageMax) {
  if (percentage == null) return '?%';
  final low = _trim(percentage);
  if (percentageMax == null || percentageMax == percentage) return '$low%';
  return '$low–${_trim(percentageMax)}%';
}

String _trim(double value) {
  final fixed = value.toStringAsFixed(1);
  return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
}
