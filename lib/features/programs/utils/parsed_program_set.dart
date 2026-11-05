/// One percentage-mode set staged for insert by [SetEditor]'s "Add sets (%)"
/// dialog, before `ProgramDetailNotifier.addPercentageSets` writes it.
/// Template equivalent of `ParsedSet`.
class ParsedProgramSet {
  const ParsedProgramSet(
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
