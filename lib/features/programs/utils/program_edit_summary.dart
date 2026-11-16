import '../../../core/utils/percent_range.dart';
import '../../../core/utils/weight_converter.dart';
import '../../../shared/models/set_type.dart';
import '../../../shared/widgets/summary_card.dart';
import '../../workouts/utils/set_resolver.dart';
import '../models/program_day.dart';
import '../models/program_exercise.dart';
import '../models/program_set.dart';
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

/// The sets a summary describes: the working sets, or all of them when the
/// exercise has none (see [countedSets]).
List<ProgramSet> _summarized(ProgramExercise exercise) => countedSets(exercise.sets, (s) => s.setType);

/// The sets left out of [_summarized], as "2 warm-up" or "2 warm-up · 1
/// cool-down"; null when every set is summarized.
String? _extraSets(ProgramExercise exercise) {
  if (_summarized(exercise).length == exercise.sets.length) return null;
  final parts = [
    for (final type in [SetType.warmup, SetType.cooldown])
      if (exercise.sets.where((s) => s.setType == type).length case final n when n > 0)
        '$n ${type.label.toLowerCase()}',
  ];
  return parts.join(' · ');
}

/// "4 × 3" when every working set shares its reps, else "4 sets"; "No sets"
/// when it has none.
String _workingSetsSummary(ProgramExercise exercise) {
  final sets = _summarized(exercise);
  if (sets.isEmpty) return 'No sets';
  final first = sets.first;
  final uniform = sets.every((s) => s.targetReps == first.targetReps && s.targetRepsMax == first.targetRepsMax);
  return uniform ? '${sets.length} × ${repsNumber(first.targetReps, first.targetRepsMax)}' : pluralize(sets.length, 'set');
}

/// The exercise's working sets as "4 × 3" when they share their reps, else
/// "4 sets", then any warm-ups and cool-downs: "4 × 3 · 2 warm-up". "No sets"
/// when it has none.
String exerciseSetsSummary(ProgramExercise exercise) =>
    [_workingSetsSummary(exercise), ?_extraSets(exercise)].join(' · ');

/// What the exercise is loaded with, as the prescription reads on a coach's
/// sheet: "20 kg", "60–80 kg", "80%", "70–90%", "100% of Snatch",
/// "choose load", or "mixed loads" when its sets use different kinds. Null
/// when it has no sets. Percentages stay percentages: the editor shows what
/// was programmed, not the viewer's resolved load. Describes the working sets
/// only, so lighter warm-ups don't widen the range.
String? exerciseLoadSummary(ProgramExercise exercise, String unit) {
  final sets = _summarized(exercise);
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

/// "4 × 3 · 20 kg", or "4 × 3 · 20 kg · 2 warm-up": an exercise on one line.
String exerciseLine(ProgramExercise exercise, String unit) =>
    [_workingSetsSummary(exercise), ?exerciseLoadSummary(exercise, unit), ?_extraSets(exercise)].join(' · ');
