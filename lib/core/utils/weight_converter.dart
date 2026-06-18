double kgToLbs(double kg) => kg * 2.20462262;
double lbsToKg(double lbs) => lbs * 0.45359237;

/// Formats a weight stored in kg for display in the user's preferred unit.
/// Rounds to 1 decimal place.
String formatWeight(double weightKg, String unit) {
  final value = unit == 'lbs' ? kgToLbs(weightKg) : weightKg;
  return '${value.toStringAsFixed(1)} $unit';
}
