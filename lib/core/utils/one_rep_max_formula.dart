/// The three formulas the strength-and-conditioning field uses to estimate a
/// one-rep max from a submaximal set. Which one a user gets is their own
/// preference (`profiles.one_rep_max_formula`) — they disagree by several
/// kilos at the same reps, and lifters have strong opinions about which one
/// flatters or under-sells them.
enum OneRepMaxFormula {
  /// `weight / (1.0278 - 0.0278 * reps)`. Linear; assumes each extra rep costs
  /// ~2.78% of max. Most accurate in the 1-5 rep range. The app default.
  brzycki,

  /// `weight * (1 + reps / 30)`. Assumes ~3.33% per rep, so it's the most
  /// generous of the three at higher reps.
  epley,

  /// `(100 * weight) / (101.3 - 2.6712 * reps)`. Non-linear; favoured in
  /// academic work for modelling how fatigue actually accumulates.
  lander,
}

/// Reps beyond this are outside every formula's usable range.
///
/// All three degrade badly past ~10 reps, and Lander's denominator crosses
/// zero near 38 reps, so estimates are simply withheld above this rather than
/// shown with a caveat.
const kMaxEstimableReps = 10;

/// Parses the `profiles.one_rep_max_formula` column. Anything unrecognised —
/// including null, for a profile row that predates the column — falls back to
/// the default rather than throwing, matching how [unitPreference] treats a
/// missing profile.
OneRepMaxFormula oneRepMaxFormulaFromDb(String? value) => switch (value) {
      'epley' => OneRepMaxFormula.epley,
      'lander' => OneRepMaxFormula.lander,
      _ => OneRepMaxFormula.brzycki,
    };

/// The value stored in `profiles.one_rep_max_formula`.
String oneRepMaxFormulaToDb(OneRepMaxFormula formula) => switch (formula) {
      OneRepMaxFormula.brzycki => 'brzycki',
      OneRepMaxFormula.epley => 'epley',
      OneRepMaxFormula.lander => 'lander',
    };

/// The formula's name as shown to the user.
String oneRepMaxFormulaLabel(OneRepMaxFormula formula) => switch (formula) {
      OneRepMaxFormula.brzycki => 'Brzycki',
      OneRepMaxFormula.epley => 'Epley',
      OneRepMaxFormula.lander => 'Lander',
    };

/// Estimated 1RM for a set of [reps] at [weightKg].
///
/// Returns [weightKg] unchanged at 1 rep — every formula collapses to identity
/// there, so a measured single needs no adjustment. Returns null below 1 rep
/// or above [kMaxEstimableReps], where the formulas stop meaning anything;
/// callers must render nothing rather than substituting the raw weight.
///
/// The maths is linear in weight, so despite the `Kg` name this works in any
/// unit — it's named for the kg-everywhere storage convention.
double? estimateOneRepMaxKg({
  required double weightKg,
  required int reps,
  required OneRepMaxFormula formula,
}) {
  if (reps < 1 || reps > kMaxEstimableReps) return null;
  if (reps == 1) return weightKg;

  return switch (formula) {
    OneRepMaxFormula.brzycki => weightKg / (1.0278 - 0.0278 * reps),
    OneRepMaxFormula.epley => weightKg * (1 + reps / 30),
    OneRepMaxFormula.lander => (100 * weightKg) / (101.3 - 2.6712 * reps),
  };
}
