/// Label for a set's rep target: "5 reps", "1 rep", "7–9 reps", or "- reps"
/// when no target was set.
///
/// [targetRepsMax] is the top of a rep range. A null or equal value means a
/// single rep count, so a range that collapses to one number reads like one.
String formatTargetReps(int? targetReps, int? targetRepsMax) {
  if (targetReps == null) return '- reps';
  if (targetRepsMax == null || targetRepsMax == targetReps) {
    return targetReps == 1 ? '1 rep' : '$targetReps reps';
  }
  return '$targetReps–$targetRepsMax reps';
}
