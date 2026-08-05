/// Presentation-only view of a set for authoring UIs (add/remove sets,
/// pick a percentage basis). Both `WorkoutSet` and `ProgramSet` map to this
/// so `SetEditor` can be shared between editing a logged workout and
/// authoring a program — deliberately excludes logging-only fields
/// (`completed`, `actualWeightKg`, `actualReps`), which stay workout-only.
class EditableSetRow {
  const EditableSetRow({
    required this.id,
    required this.weightMode,
    this.targetReps,
    this.percentage,
    this.absoluteWeightKg,
    this.basisExerciseId,
    this.basisExerciseName,
  });

  final String id;
  final int? targetReps;
  final String weightMode; // 'percentage' | 'absolute'
  final double? percentage;
  final double? absoluteWeightKg;
  final String? basisExerciseId;
  final String? basisExerciseName;
}
