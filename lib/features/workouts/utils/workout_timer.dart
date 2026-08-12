/// Elapsed workout time, reused for the running (ticking), paused (frozen),
/// and finished (frozen) displays. [finishedAt] and [pausedAt] are mutually
/// exclusive by construction — the workout_*_session RPCs never set both —
/// so whichever is present (in that priority order) freezes the end point;
/// otherwise elapsed is computed live against [DateTime.now()].
Duration computeElapsed({
  required DateTime startedAt,
  required int totalPausedSeconds,
  DateTime? pausedAt,
  DateTime? finishedAt,
}) {
  final end = finishedAt ?? pausedAt ?? DateTime.now();
  final raw = end.difference(startedAt) - Duration(seconds: totalPausedSeconds);
  return raw.isNegative ? Duration.zero : raw;
}
