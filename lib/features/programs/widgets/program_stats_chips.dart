import '../../../shared/widgets/summary_card.dart';
import 'package:flutter/material.dart';
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
