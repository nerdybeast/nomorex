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
