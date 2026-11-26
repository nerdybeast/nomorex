import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ai_import_alerts_provider.g.dart';

/// The snackbars `AiImportJobAlerts` has shown, by job, so opening a job's
/// review some other way (Home's Review button) can take its alert away.
@Riverpod(keepAlive: true)
ImportAlertSnackBars importAlertSnackBars(Ref ref) => ImportAlertSnackBars();

class ImportAlertSnackBars {
  // In the order shown, which is the order ScaffoldMessenger shows them.
  final _open = <(String, ScaffoldFeatureController<SnackBar, SnackBarClosedReason>)>[];

  void add(String jobId, ScaffoldFeatureController<SnackBar, SnackBarClosedReason> controller) {
    final entry = (jobId, controller);
    _open.add(entry);
    controller.closed.whenComplete(() => _open.remove(entry));
  }

  final _opened = <String>{};

  /// Marks [jobId] as opened already, so it never alerts: the import screen
  /// opens a run's review itself as soon as the result is saved.
  void suppress(String jobId) => _opened.add(jobId);

  bool isSuppressed(String jobId) => _opened.contains(jobId);

  /// Closes [jobId]'s alert if it's the one on screen. A queued one can't be
  /// closed (ScaffoldMessenger only closes the current snackbar), so it still
  /// shows for its duration.
  void dismiss(String jobId) {
    if (_open.isNotEmpty && _open.first.$1 == jobId) _open.first.$2.close();
  }
}
