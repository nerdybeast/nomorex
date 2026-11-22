import '../../../shared/widgets/summary_card.dart';
import '../models/program_day.dart';
import '../models/program_exercise.dart';
import '../models/program_session.dart';

/// Subtitle text for a [ProgramDayCard] summarizing what's scheduled on
/// [day] — shared between the template browse screen, the running instance
/// screen and Community so they don't drift.
///
/// Names the lifts ("Back squat · Clean · Bench  +3 more") rather than
/// counting them: a lifter judging a program, or checking what's on Day 4,
/// shouldn't have to open every day to find out.
///
/// A day split into sessions leads with how many: "2 sessions · Snatch · …".
String programDaySubtitle(ProgramDay day) {
  if (day.isRestDay) return 'Rest day';
  if (day.exercises.isEmpty) return 'No workout scheduled';
  final lifts = _lifts(day.exercises);
  final sessions = day.hasMultipleSessions ? '${pluralize(day.sessions.length, 'session')} · ' : '';
  final notes = day.notes;
  return notes != null && notes.isNotEmpty ? '$notes · $sessions$lifts' : '$sessions$lifts';
}

String _lifts(List<ProgramExercise> exercises) {
  final names = [for (final e in exercises) if (e.exerciseName.isNotEmpty) e.exerciseName];
  return names.isEmpty ? pluralize(exercises.length, 'exercise') : exercisePreview(names);
}

/// "Day 1 · AM": a session's row on a run, named like the workout
/// `start_program` makes of it ("Session N" when untitled).
String programSessionTitle(ProgramDay day, int index) => '${day.title} · ${day.sessions[index].label(index)}';

/// The lifts of one session, after its notes when it has any.
String programSessionSubtitle(ProgramSession session) {
  if (session.exercises.isEmpty) return 'No workout scheduled';
  final lifts = _lifts(session.exercises);
  final notes = session.notes?.trim();
  return notes != null && notes.isNotEmpty ? '$notes · $lifts' : lifts;
}

/// Whether [day] has anything worth tapping into (drives the chevron).
bool programDayHasContent(ProgramDay day) => !day.isRestDay && day.exercises.isNotEmpty;
