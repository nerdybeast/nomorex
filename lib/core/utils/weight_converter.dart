double kgToLbs(double kg) => kg * 2.20462262;
double lbsToKg(double lbs) => lbs * 0.45359237;

/// Formats a weight stored in kg for display in the user's preferred unit.
/// Rounds to 1 decimal place.
String formatWeight(double weightKg, String unit) {
  final value = unit == 'lbs' ? kgToLbs(weightKg) : weightKg;
  return '${value.toStringAsFixed(1)} $unit';
}

/// Formats a weight stored in kg for display in both units at once,
/// rounded to whole numbers (e.g. "192 lbs / 87 kg").
String formatWeightBoth(double weightKg) {
  final lbs = kgToLbs(weightKg).round();
  final kg = weightKg.round();
  return '$lbs lbs / $kg kg';
}

/// Formats a weight stored in kg according to the user's unit preference —
/// both units at once when the preference is 'both', otherwise just the one.
String formatWeightForPreference(double weightKg, String preference) {
  return preference == 'both'
      ? formatWeightBoth(weightKg)
      : formatWeight(weightKg, preference);
}

/// A weight resolved from a 1RM, marked when that 1RM was estimated from a
/// multi-rep PR rather than measured as a true single. Centralized so the
/// marker can't drift between the workout, program, and community screens.
String formatResolvedWeight(
  double weightKg,
  String preference, {
  required bool estimated,
}) {
  final formatted = formatWeightForPreference(weightKg, preference);
  return estimated ? '$formatted (est.)' : formatted;
}
