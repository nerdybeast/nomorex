double kgToLbs(double kg) => kg * 2.20462262;
double lbsToKg(double lbs) => lbs * 0.45359237;

// Caps precision at 1 decimal place but drops a trailing ".0" so a whole
// number reads as "205", not "205.0" — mirrors NumberStepperField's display
// formatting so input and read-only weight displays agree.
String _trimTrailingZeros(String fixed) {
  if (!fixed.contains('.')) return fixed;
  final trimmed = fixed.replaceFirst(RegExp(r'0+$'), '');
  return trimmed.endsWith('.') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
}

/// Formats a weight stored in kg for display in the user's preferred unit.
/// Rounds to 1 decimal place, trimmed of a trailing ".0" for whole numbers.
String formatWeight(double weightKg, String unit) {
  final value = unit == 'lbs' ? kgToLbs(weightKg) : weightKg;
  return '${_trimTrailingZeros(value.toStringAsFixed(1))} $unit';
}

/// Formats a weight stored in kg for display in both units at once
/// (e.g. "192 lbs / 87.5 kg"). The lbs side is an approximate derived
/// conversion, so it's rounded to a whole number; the kg side is the
/// canonical stored value, so it keeps whatever precision the user entered.
String formatWeightBoth(double weightKg) {
  final lbs = kgToLbs(weightKg).round();
  final kg = _trimTrailingZeros(weightKg.toStringAsFixed(1));
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
