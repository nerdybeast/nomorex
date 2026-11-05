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
    this.targetRepsMax,
    this.percentage,
    this.percentageMax,
    this.rpeMin,
    this.rpeMax,
    this.absoluteWeightKg,
    this.basisExerciseId,
    this.basisExerciseName,
  });

  final String id;
  final int? targetReps;
  /// Top of a rep range; null means a single rep count ([targetReps]).
  final int? targetRepsMax;
  final String weightMode; // 'percentage' | 'absolute'
  final double? percentage;
  /// Top of a %1RM range; null means a single percentage.
  final double? percentageMax;
  /// Target effort (1–10); null means none prescribed.
  final double? rpeMin;
  /// Top of an RPE range; null means a single RPE ([rpeMin]).
  final double? rpeMax;
  final double? absoluteWeightKg;
  final String? basisExerciseId;
  final String? basisExerciseName;
}
