/// One percentage-mode set staged for insert by [SetEditor]'s "Add sets (%)"
/// dialog, before `ProgramDetailNotifier.addPercentageSets` writes it.
/// Template equivalent of `ParsedSet`.
class ParsedProgramSet {
  const ParsedProgramSet(this.targetReps, this.percentage, [this.basisExerciseId]);
  final int targetReps;
  final double percentage;
  final String? basisExerciseId;
}
