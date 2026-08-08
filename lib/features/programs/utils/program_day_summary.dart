import '../models/program_day.dart';

/// Subtitle text for a [ProgramDayCard] summarizing what's scheduled on
/// [day] — shared between the template browse screen and the running
/// instance screen so the two don't drift.
String programDaySubtitle(ProgramDay day) {
  if (day.isRestDay) return 'Rest day';
  if (day.exercises.isEmpty) return 'No workout scheduled';
  final count = day.exercises.length;
  final exerciseWord = count == 1 ? 'exercise' : 'exercises';
  final notes = day.notes;
  return notes != null && notes.isNotEmpty ? '$notes · $count $exerciseWord' : '$count $exerciseWord';
}

/// Whether [day] has anything worth tapping into (drives the chevron).
bool programDayHasContent(ProgramDay day) => !day.isRestDay && day.exercises.isNotEmpty;
