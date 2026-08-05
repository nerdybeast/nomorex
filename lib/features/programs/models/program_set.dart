import '../../../shared/models/editable_set_row.dart';

/// Template equivalent of [WorkoutSet] — same shape minus the logging-only
/// fields (`completed`, `actualWeightKg`, `actualReps`), which stay
/// workout-only.
class ProgramSet {
  const ProgramSet({
    required this.id,
    required this.programExerciseId,
    required this.position,
    required this.weightMode,
    this.targetReps,
    this.percentage,
    this.absoluteWeightKg,
    this.note,
    this.basisExerciseId,
    this.basisExerciseName,
  });

  final String id;
  final String programExerciseId;
  final int position;
  final String weightMode; // 'percentage' | 'absolute'
  final int? targetReps;
  final double? percentage;
  final double? absoluteWeightKg;
  final String? note;
  final String? basisExerciseId;
  final String? basisExerciseName;

  factory ProgramSet.fromJson(Map<String, dynamic> json) {
    final basisExerciseMap = json['exercises'] as Map<String, dynamic>?;
    return ProgramSet(
      id: json['id'] as String,
      programExerciseId: json['program_exercise_id'] as String,
      position: json['position'] as int,
      weightMode: json['weight_mode'] as String,
      targetReps: json['target_reps'] as int?,
      percentage: (json['percentage'] as num?)?.toDouble(),
      absoluteWeightKg: (json['absolute_weight_kg'] as num?)?.toDouble(),
      note: json['note'] as String?,
      basisExerciseId: json['basis_exercise_id'] as String?,
      basisExerciseName: basisExerciseMap?['name'] as String?,
    );
  }

  EditableSetRow toEditableRow() => EditableSetRow(
        id: id,
        targetReps: targetReps,
        weightMode: weightMode,
        percentage: percentage,
        absoluteWeightKg: absoluteWeightKg,
        basisExerciseId: basisExerciseId,
        basisExerciseName: basisExerciseName,
      );
}
