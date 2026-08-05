/// One percentage-mode set staged for insert by [SetEditor]'s "Add sets (%)"
/// dialog, before `WorkoutDetailNotifier.addPercentageSets` writes it.
class ParsedSet {
  const ParsedSet(this.targetReps, this.percentage, [this.basisExerciseId]);
  final int targetReps;
  final double percentage;
  final String? basisExerciseId;
}
