import '../../../core/utils/percent_range.dart';
import '../../../core/utils/weight_converter.dart';
import '../../../shared/widgets/summary_card.dart';
import '../../workouts/utils/set_resolver.dart';
import '../models/program_day.dart';
import '../models/program_exercise.dart';
import '../models/program_week.dart';
import 'program_day_brief.dart';

/// "Week 1 · Meso 1/4", or "Week 1" with no label.
String weekTitle(ProgramWeek week) {
  final label = week.label?.trim();
  return label == null || label.isEmpty ? 'Week ${week.weekNumber}' : 'Week ${week.weekNumber} · $label';
}

/// "6 exercises · 24 sets", "Rest day", or "No exercises yet".
String daySummary(ProgramDay day) {
  if (day.isRestDay) return 'Rest day';
  if (day.exercises.isEmpty) return 'No exercises yet';
  return '${pluralize(day.exercises.length, 'exercise')} · ${pluralize(totalSets(day), 'set')}';
}

/// "5 days · 26 exercises".
String weekSummary(ProgramWeek week) {
  final exercises = week.days.fold<int>(0, (n, d) => n + d.exercises.length);
  return '${pluralize(week.days.length, 'day')} · ${pluralize(exercises, 'exercise')}';
}

/// The exercise's sets as "4 × 3" when every set shares its reps, else
/// "4 sets"; "No sets" when it has none.
String exerciseSetsSummary(ProgramExercise exercise) {
  final sets = exercise.sets;
  if (sets.isEmpty) return 'No sets';
  final first = sets.first;
  final uniform = sets.every((s) => s.targetReps == first.targetReps && s.targetRepsMax == first.targetRepsMax);
  return uniform ? '${sets.length} × ${repsNumber(first.targetReps, first.targetRepsMax)}' : pluralize(sets.length, 'set');
}

/// What the exercise is loaded with, as the prescription reads on a coach's
/// sheet: "20 kg", "60–80 kg", "80%", "70–90%", "100% of Snatch",
/// "choose load", or "mixed loads" when its sets use different kinds. Null
/// when it has no sets. Percentages stay percentages: the editor shows what
/// was programmed, not the viewer's resolved load.
String? exerciseLoadSummary(ProgramExercise exercise, String unit) {
  final sets = exercise.sets;
  if (sets.isEmpty) return null;
  final modes = sets.map((s) => s.weightMode).toSet();
  if (modes.length > 1) return 'mixed loads';
  switch (modes.single) {
    case 'percentage':
      double? low;
      double? high;
      for (final s in sets) {
        final lo = s.percentage;
        final hi = s.percentageMax ?? s.percentage;
        if (lo != null && (low == null || lo < low)) low = lo;
        if (hi != null && (high == null || hi > high)) high = hi;
      }
      final pct = formatPercentTarget(low, high == low ? null : high);
      final bases = sets.map((s) => s.basisExerciseId).toSet();
      final basisName = sets.first.basisExerciseName;
      final ofOther = bases.length == 1 &&
          sets.first.basisExerciseId != null &&
          basisName != null &&
          basisName.toLowerCase() != exercise.exerciseName.toLowerCase();
      return ofOther ? '$pct of $basisName' : pct;
    case 'absolute':
      final kgs = [for (final s in sets) ?s.absoluteWeightKg];
      if (kgs.isEmpty) return null;
      kgs.sort();
      return formatWeightRangeForPreference(kgs.first, kgs.last == kgs.first ? null : kgs.last, unit);
    default:
      return kOpenLoadLabel;
  }
}

/// "4 × 3 · 20 kg": an exercise on one line.
String exerciseLine(ProgramExercise exercise, String unit) {
  final load = exerciseLoadSummary(exercise, unit);
  final sets = exerciseSetsSummary(exercise);
  return load == null ? sets : '$sets · $load';
}
