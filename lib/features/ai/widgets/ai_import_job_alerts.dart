import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/ai_import_job.dart';
import '../providers/ai_import_intake_provider.dart';
import '../providers/ai_import_jobs_provider.dart';
import '../utils/import_alert_tracker.dart';

/// Wraps the whole app (`MaterialApp.router`'s `builder`) to keep import jobs
/// current and to alert on any screen when one finishes.
///
/// - Keeps [aiImportJobWatchProvider] alive, which subscribes to Realtime
///   while a job is processing.
/// - Re-reads the jobs and limits when the app resumes, since nothing reaches
///   a backgrounded app.
/// - Shows one floating snackbar per job that becomes ready or failed.
///   Floating, so it sits above the shell's FAB and bottom bar rather than
///   pushing them.
///
/// It sits above the app's `Router`, so it can't use `context.push`;
/// [navigate] does that instead.
class AiImportJobAlerts extends ConsumerStatefulWidget {
  const AiImportJobAlerts({super.key, required this.navigate, required this.child});

  final void Function(String location) navigate;
  final Widget child;

  @override
  ConsumerState<AiImportJobAlerts> createState() => _AiImportJobAlertsState();
}

class _AiImportJobAlertsState extends ConsumerState<AiImportJobAlerts> {
  final _tracker = ImportAlertTracker();
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        ref.invalidate(aiImportJobsProvider);
        // Picks up the off switch, which shows or hides the entry points.
        ref.invalidate(aiImportLimitsProvider);
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _onJobs(List<AiImportJob> jobs) {
    final maxJobSeconds = jobs.any((j) => j.status == 'processing')
        ? ref.read(aiImportLimitsProvider).value?.maxJobSeconds ?? 180
        : 180;
    final alerts = _tracker.update(jobs, DateTime.now(), maxJobSeconds);
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    for (final job in alerts) {
      final ready = job.state(DateTime.now(), maxJobSeconds) == AiImportJobState.ready;
      final thing = switch (job.type) {
        'program' => 'program',
        'workout' => 'workout',
        _ => 'import',
      };
      messenger.showSnackBar(
        SnackBar(
          key: Key('ai_import_alert_${job.id}'),
          behavior: SnackBarBehavior.floating,
          // Full width on phones; a card-sized toast beside the rail on wider screens.
          width: MediaQuery.sizeOf(context).width >= AppConstants.kMobileBreakpoint ? 480 : null,
          duration: const Duration(seconds: 8),
          content: Text(
            ready
                ? 'Your imported $thing is ready to review.'
                : 'An import failed. ${job.failureMessage(DateTime.now(), maxJobSeconds)}',
          ),
          action: SnackBarAction(
            label: ready ? 'Review' : 'View',
            onPressed: () => widget.navigate(ready ? AppConstants.routeAiImportReview(job.id) : AppConstants.routeHome),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(aiImportJobWatchProvider);
    ref.listen(currentAuthUserProvider, (previous, next) {
      if (previous?.id != next?.id) _tracker.reset();
    });
    ref.listen(aiImportJobsProvider, (_, next) {
      final jobs = next.value;
      if (jobs != null && !next.isLoading) _onJobs(jobs);
    });
    return widget.child;
  }
}
