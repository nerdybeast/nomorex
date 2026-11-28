import '../../../core/utils/percent_range.dart';
import '../../../core/utils/weight_converter.dart';
import '../../../shared/models/editable_set_row.dart';
import '../../../shared/models/set_type.dart';
import '../../../shared/widgets/summary_card.dart';
import '../../workouts/utils/set_resolver.dart';
import '../models/program_day.dart';
import '../models/program_exercise.dart';
import '../models/program_session.dart';
import '../models/program_week.dart';
import 'program_day_brief.dart';

/// "Week 1 · Meso 1/4", or "Week 1" with no label.
String weekTitle(ProgramWeek week) {
  final label = week.label?.trim();
  return label == null || label.isEmpty ? 'Week ${week.weekNumber}' : 'Week ${week.weekNumber} · $label';
}

/// "6 exercises · 24 sets", "2 sessions · 6 exercises · 24 sets", "Rest
/// day", or "No exercises yet".
String daySummary(ProgramDay day) {
  if (day.isRestDay) return 'Rest day';
  final sessions = day.hasMultipleSessions ? '${pluralize(day.sessions.length, 'session')} · ' : '';
  if (day.exercises.isEmpty) return '${sessions}No exercises yet';
  return '$sessions${pluralize(day.exercises.length, 'exercise')} · ${pluralize(totalSets(day), 'set')}';
}

/// "3 exercises · 12 sets", or "No exercises yet", for one session.
String sessionSummary(ProgramSession session) {
  if (session.exercises.isEmpty) return 'No exercises yet';
  final sets = session.exercises.fold<int>(0, (n, e) => n + e.sets.length);
  return '${pluralize(session.exercises.length, 'exercise')} · ${pluralize(sets, 'set')}';
}

/// "5 days · 26 exercises".
String weekSummary(ProgramWeek week) {
  final exercises = week.days.fold<int>(0, (n, d) => n + d.exercises.length);
  return '${pluralize(week.days.length, 'day')} · ${pluralize(exercises, 'exercise')}';
}

/// [exercise]'s sets as the editors see them. The summaries below read these,
/// so a workout's sets (`WorkoutSet.toEditableRow`) summarize the same way.
List<EditableSetRow> _rows(ProgramExercise exercise) => [for (final s in exercise.sets) s.toEditableRow()];

/// The sets a summary describes: the working sets, or all of them when the
/// exercise has none (see [countedSets]).
List<EditableSetRow> _summarized(List<EditableSetRow> sets) => countedSets(sets, (s) => s.setType);

/// The sets left out of [_summarized], as "2 warm-up" or "2 warm-up · 1
/// cool-down"; null when every set is summarized.
String? _extraSets(List<EditableSetRow> sets) {
  if (_summarized(sets).length == sets.length) return null;
  final parts = [
    for (final type in [SetType.warmup, SetType.cooldown])
      if (sets.where((s) => s.setType == type).length case final n when n > 0) '$n ${type.label.toLowerCase()}',
  ];
  return parts.join(' · ');
}

/// "4 × 3" when every working set shares its reps, else "4 sets"; "No sets"
/// when it has none.
String _workingSetsSummary(List<EditableSetRow> all) {
  final sets = _summarized(all);
  if (sets.isEmpty) return 'No sets';
  final first = sets.first;
  final uniform = sets.every((s) => s.targetReps == first.targetReps && s.targetRepsMax == first.targetRepsMax);
  return uniform ? '${sets.length} × ${repsNumber(first.targetReps, first.targetRepsMax)}' : pluralize(sets.length, 'set');
}

/// The exercise's working sets as "4 × 3" when they share their reps, else
/// "4 sets", then any warm-ups and cool-downs: "4 × 3 · 2 warm-up". "No sets"
/// when it has none.
String exerciseSetsSummary(ProgramExercise exercise) {
  final rows = _rows(exercise);
  return [_workingSetsSummary(rows), ?_extraSets(rows)].join(' · ');
}

/// What the exercise is loaded with, as the prescription reads on a coach's
/// sheet: "20 kg", "60–80 kg", "80%", "70–90%", "100% of Snatch",
/// "choose load", or "mixed loads" when its sets use different kinds. Null
/// when it has no sets. Percentages stay percentages: the editor shows what
/// was programmed, not the viewer's resolved load. Describes the working sets
/// only, so lighter warm-ups don't widen the range.
String? exerciseLoadSummary(ProgramExercise exercise, String unit) =>
    _loadSummary(exercise.exerciseName, _rows(exercise), unit);

String? _loadSummary(String exerciseName, List<EditableSetRow> all, String unit) {
  final sets = _summarized(all);
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
          basisName.toLowerCase() != exerciseName.toLowerCase();
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
String exerciseLine(ProgramExercise exercise, String unit) => setsLine(exercise.exerciseName, _rows(exercise), unit);

/// [exerciseLine] for any exercise's sets, a workout's included.
String setsLine(String exerciseName, List<EditableSetRow> sets, String unit) =>
    [_workingSetsSummary(sets), ?_loadSummary(exerciseName, sets, unit), ?_extraSets(sets)].join(' · ');
