/// RPE (rate of perceived exertion) is prescribed and logged on a 1–10 scale
/// in half steps, e.g. "RPE 7.5".
const double kRpeMin = 1;
const double kRpeMax = 10;
const double kRpeStep = 0.5;

/// "8", "7.5": at most one decimal, no trailing ".0".
String formatRpe(double rpe) {
  final fixed = rpe.toStringAsFixed(1);
  return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
}

/// "RPE 8" or "RPE 6–7", or null when no RPE is prescribed so callers can
/// leave it out entirely. A range collapsed to one number reads as one.
String? formatRpeTarget(double? rpeMin, double? rpeMax) {
  if (rpeMin == null) return null;
  if (rpeMax == null || rpeMax == rpeMin) return 'RPE ${formatRpe(rpeMin)}';
  return 'RPE ${formatRpe(rpeMin)}–${formatRpe(rpeMax)}';
}
