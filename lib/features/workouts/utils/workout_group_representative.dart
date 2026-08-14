import '../models/workout.dart';

/// Picks the single row that should represent a workout-group in the
/// Workouts list: an active session takes priority, then a ready-to-go
/// not-started instance, then (a fallback for a group with no live sibling
/// yet, e.g. data from before eager "next instance" creation existed) the
/// most recently finished one. Returns null for an empty group.
Workout? pickGroupRepresentative(List<Workout> group) {
  for (final w in group) {
    if (w.status == 'in_progress' || w.status == 'paused') return w;
  }
  for (final w in group) {
    if (w.status == 'not_started') return w;
  }
  if (group.isEmpty) return null;
  final finished = [...group]
    ..sort((a, b) => (b.finishedAt ?? b.updatedAt).compareTo(a.finishedAt ?? a.updatedAt));
  return finished.first;
}
