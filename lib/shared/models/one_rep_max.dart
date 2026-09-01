/// A lifter's 1RM for one exercise, and whether it was actually measured.
///
/// [isEstimated] is false only for a genuine `reps = 1` personal best; when
/// the user has never tested a single, [kg] is derived from their best
/// multi-rep PR via `estimateOneRepMaxKg`. Every surface that renders a weight
/// resolved from this has to carry the distinction through — an inferred load
/// must never look like a measured one.
class OneRepMax {
  const OneRepMax({required this.kg, required this.isEstimated});

  /// A genuine `reps = 1` personal best.
  const OneRepMax.measured(this.kg) : isEstimated = false;

  /// Inferred from a multi-rep personal best via `estimateOneRepMaxKg`.
  const OneRepMax.estimated(this.kg) : isEstimated = true;

  final double kg;
  final bool isEstimated;
}
