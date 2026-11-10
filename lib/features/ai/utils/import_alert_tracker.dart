import '../models/ai_import_job.dart';

/// Decides which import jobs deserve an alert, so each finished job alerts
/// at most once per session.
///
/// The first list it sees is the baseline: jobs that were already ready or
/// failed when the app loaded are on the Home card, so they don't alert.
/// After that, a job alerts when it's first seen as ready or failed, whether
/// it was processing before or is new (started on another device).
class ImportAlertTracker {
  final Map<String, AiImportJobState> _states = {};
  final Set<String> _alerted = {};
  bool _primed = false;

  /// Records [jobs] and returns the ones to alert about now.
  List<AiImportJob> update(List<AiImportJob> jobs, DateTime now, int maxJobSeconds) {
    final alerts = <AiImportJob>[];
    for (final job in jobs) {
      final state = job.state(now, maxJobSeconds);
      if (state == null) continue;
      final previous = _states[job.id];
      _states[job.id] = state;
      if (!_primed || state == AiImportJobState.processing) continue;
      if (previous != state && _alerted.add(job.id)) alerts.add(job);
    }
    _primed = true;
    return alerts;
  }

  /// Forgets everything, e.g. when the user changes.
  void reset() {
    _states.clear();
    _alerted.clear();
    _primed = false;
  }
}
