import '../../../shared/widgets/summary_card.dart';
import 'package:material_ui/material_ui.dart';
import '../utils/program_stats.dart';

/// The weeks / days / workouts facts for a program, as chips. A running (or
/// ended) program reads "2 of 8 weeks"; one that hasn't been started reads
/// "8 weeks". Shared by the Programs list, the dashboard and Program history
/// so all three say the same thing.
List<SummaryInfoChip> programStatsChips(ProgramStats stats) {
  String label(int total, int? done, String noun) =>
      done == null ? pluralize(total, noun) : '$done of ${pluralize(total, noun)}';

  return [
    SummaryInfoChip(
      Icons.calendar_view_week_outlined,
      label(stats.weeks, stats.completedWeeks, 'week'),
    ),
    if (stats.days > 0) ...[
      SummaryInfoChip(
        Icons.today_outlined,
        label(stats.days, stats.completedDays, 'day'),
      ),
      SummaryInfoChip(
        Icons.fitness_center_outlined,
        label(stats.workouts, stats.completedWorkouts, 'workout'),
      ),
    ],
  ];
}

/// The facts on a Programs list row, which are about choosing a program
/// rather than tracking one: how long it is and how many days a week it asks
/// for ([daysPerWeek], see `daysPerWeekLabel`), plus, for a run, how many of
/// its workouts are done.
///
/// No day count: it includes rest days, so a 6-week program read "37 days",
/// which looked like an error next to its workouts. [showWeeks] is false
/// when the run's status line already says "Week 2 of 6".
List<SummaryInfoChip> programListChips(ProgramStats stats, {String? daysPerWeek, bool showWeeks = true}) => [
  if (showWeeks) SummaryInfoChip(Icons.calendar_view_week_outlined, pluralize(stats.weeks, 'week')),
  if (daysPerWeek != null) SummaryInfoChip(Icons.today_outlined, daysPerWeek),
  if (stats.isRun && stats.workouts > 0)
    SummaryInfoChip(
      Icons.fitness_center_outlined,
      // As on Home; "done" made it wrap on a phone.
      '${stats.completedWorkouts} of ${pluralize(stats.workouts, 'workout')}',
    ),
];
