/// One percentage-mode set staged for insert by [SetEditor]'s "Add sets (%)"
/// dialog, before `WorkoutDetailNotifier.addPercentageSets` writes it.
/// Every optional field is null for "not prescribed" / "a single value".
class ParsedSet {
  const ParsedSet(
    this.targetReps,
    this.percentage, {
    this.basisExerciseId,
    this.targetRepsMax,
    this.percentageMax,
    this.rpeMin,
    this.rpeMax,
  });
  final int targetReps;
  /// Top of a rep range; null means a single rep count ([targetReps]).
  final int? targetRepsMax;
  final double percentage;
  /// Top of a %1RM range; null means a single percentage.
  final double? percentageMax;
  final String? basisExerciseId;
  /// Target effort; null means none prescribed.
  final double? rpeMin;
  /// Top of an RPE range; null means a single RPE ([rpeMin]).
  final double? rpeMax;
}

/// One "Add sets (weight)" batch, before `addAbsoluteSets` writes it as
/// [sets] identical rows. [weightKg] is already converted from the dialog's
/// display unit.
class AbsoluteSetBatch {
  const AbsoluteSetBatch({
    required this.sets,
    required this.reps,
    this.repsMax,
    required this.weightKg,
    this.rpeMin,
    this.rpeMax,
  });
  final int sets;
  final int reps;
  final int? repsMax;
  final double weightKg;
  final double? rpeMin;
  final double? rpeMax;
}
