import '../../../shared/widgets/summary_card.dart';
import '../models/program_day.dart';

/// Subtitle text for a [ProgramDayCard] summarizing what's scheduled on
/// [day] — shared between the template browse screen, the running instance
/// screen and Community so they don't drift.
///
/// Names the lifts ("Back squat · Clean · Bench  +3 more") rather than
/// counting them: a lifter judging a program, or checking what's on Day 4,
/// shouldn't have to open every day to find out.
String programDaySubtitle(ProgramDay day) {
  if (day.isRestDay) return 'Rest day';
  if (day.exercises.isEmpty) return 'No workout scheduled';
  final names = [for (final e in day.exercises) if (e.exerciseName.isNotEmpty) e.exerciseName];
  final count = day.exercises.length;
  final lifts = names.isEmpty ? pluralize(count, 'exercise') : exercisePreview(names);
  final notes = day.notes;
  return notes != null && notes.isNotEmpty ? '$notes · $lifts' : lifts;
}

/// Whether [day] has anything worth tapping into (drives the chevron).
bool programDayHasContent(ProgramDay day) => !day.isRestDay && day.exercises.isNotEmpty;
