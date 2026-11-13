import '../models/program_day.dart';
import '../models/program_set.dart';

/// Consecutive sets that prescribe exactly the same thing, written the way a
/// coach would: "3 × 3 @ 70%". A change of reps, load, percentage, basis lift
/// or RPE starts a new group, so a wave (50, 60, 70, 70%) keeps its steps.
class SetGroup {
  const SetGroup(this.sets);

  final List<ProgramSet> sets;

  ProgramSet get first => sets.first;
  int get count => sets.length;
}

bool _samePrescription(ProgramSet a, ProgramSet b) =>
    a.weightMode == b.weightMode &&
    a.targetReps == b.targetReps &&
    a.targetRepsMax == b.targetRepsMax &&
    a.percentage == b.percentage &&
    a.percentageMax == b.percentageMax &&
    a.absoluteWeightKg == b.absoluteWeightKg &&
    a.rpeMin == b.rpeMin &&
    a.rpeMax == b.rpeMax &&
    a.basisExerciseId == b.basisExerciseId &&
    // The grouped editor rewrites a group as copies of its first set, so a
    // per-set note has to match too or it would be overwritten.
    a.note == b.note;

List<SetGroup> groupConsecutiveSets(List<ProgramSet> sets) {
  final groups = <List<ProgramSet>>[];
  for (final set in sets) {
    if (groups.isNotEmpty && _samePrescription(groups.last.last, set)) {
      groups.last.add(set);
    } else {
      groups.add([set]);
    }
  }
  return [for (final g in groups) SetGroup(g)];
}

/// The reps on their own, for "3 × 8–12": "8–12", "5", or "?" when unset.
String repsNumber(int? reps, int? repsMax) {
  if (reps == null) return '?';
  if (repsMax == null || repsMax == reps) return '$reps';
  return '$reps–$repsMax';
}

/// "3 × 3": the group's set count by its reps.
String setGroupLabel(SetGroup group) =>
    '${group.count} × ${repsNumber(group.first.targetReps, group.first.targetRepsMax)}';

/// The heaviest %1RM the day prescribes (a range counts at its top), or null
/// when no set is a percentage.
double? peakPercentage(ProgramDay day) {
  double? peak;
  for (final exercise in day.exercises) {
    for (final set in exercise.sets) {
      if (set.weightMode != 'percentage') continue;
      final top = set.percentageMax ?? set.percentage;
      if (top != null && (peak == null || top > peak)) peak = top;
    }
  }
  return peak;
}

/// The heaviest fixed load the day prescribes, or null when there's none.
double? peakAbsoluteKg(ProgramDay day) {
  double? peak;
  for (final exercise in day.exercises) {
    for (final set in exercise.sets) {
      if (set.weightMode != 'absolute') continue;
      final kg = set.absoluteWeightKg;
      if (kg != null && (peak == null || kg > peak)) peak = kg;
    }
  }
  return peak;
}

int totalSets(ProgramDay day) => day.exercises.fold(0, (sum, e) => sum + e.sets.length);
