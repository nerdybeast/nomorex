import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/list_group.dart';
import '../models/ai_import_job.dart';
import '../providers/ai_import_intake_provider.dart';
import '../providers/ai_import_jobs_provider.dart';

/// The Home card for imports: processing, ready to review, or failed.
///
/// Renders nothing when the user has no open imports, or while they load or
/// fail to load, so it never takes space on a Home screen that has nothing
/// to say about imports.
class AiImportJobsSection extends ConsumerStatefulWidget {
  const AiImportJobsSection({super.key});

  @override
  ConsumerState<AiImportJobsSection> createState() => _AiImportJobsSectionState();
}

class _AiImportJobsSectionState extends ConsumerState<AiImportJobsSection> {
  final Set<String> _dismissing = {};
  String? _error;

  Future<void> _dismiss(AiImportJob job) async {
    setState(() {
      _dismissing.add(job.id);
      _error = null;
    });
    try {
      await ref.read(aiImportJobsProvider.notifier).discard(job.id);
    } catch (e) {
      debugPrint('[ai_import] dismiss failed: $e');
      if (mounted) setState(() => _error = "Couldn't dismiss that import. Try again.");
    } finally {
      if (mounted) setState(() => _dismissing.remove(job.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobs = ref.watch(aiImportJobsProvider).value ?? const <AiImportJob>[];
    if (jobs.isEmpty) return const SizedBox.shrink();
    // The limits are only needed to spot a dead processing job, so they're
    // only fetched when there is one.
    final maxJobSeconds = jobs.any((j) => j.status == 'processing')
        ? ref.watch(aiImportLimitsProvider.select((l) => l.value?.maxJobSeconds)) ?? 180
        : 180;
    final now = DateTime.now();

    return Column(
      key: const Key('ai_import_jobs_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListGroup(
          header: const ListGroupHeader(title: 'IMPORTS'),
          children: [
            for (final job in jobs)
              if (job.state(now, maxJobSeconds) case final state?)
                _JobRow(
                  job: job,
                  state: state,
                  failure: state == AiImportJobState.failed ? job.failureMessage(now, maxJobSeconds) : null,
                  dismissing: _dismissing.contains(job.id),
                  onDismiss: job.canDiscard ? () => _dismiss(job) : null,
                ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            key: const Key('ai_import_jobs_error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

/// One import. Its button sits in a `Row` beside the text, not in a tile's
/// trailing slot, so it stays its own semantics node.
class _JobRow extends StatelessWidget {
  const _JobRow({
    required this.job,
    required this.state,
    required this.failure,
    required this.dismissing,
    required this.onDismiss,
  });

  final AiImportJob job;
  final AiImportJobState state;
  final String? failure;
  final bool dismissing;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = NomorexTokens.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final thing = switch (job.type) {
      'program' => 'Program',
      'workout' => 'Workout',
      _ => 'Import',
    };

    final (Widget leading, String title, String subtitle) = switch (state) {
      AiImportJobState.processing => (
        const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        'Reading your import…',
        "Usually under a minute. You'll be told when it's ready.",
      ),
      AiImportJobState.ready => (
        Icon(Icons.check_circle_outline, color: theme.colorScheme.primary),
        '$thing ready to review',
        'Check what was read before saving it.',
      ),
      AiImportJobState.failed => (
        Icon(Icons.error_outline, color: theme.colorScheme.error),
        'Import failed',
        failure ?? '',
      ),
    };

    final Widget? action = switch (state) {
      AiImportJobState.ready => FilledButton(
        key: Key('ai_import_job_review_${job.id}'),
        style: const ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(0, NomorexSizes.controlHeight))),
        onPressed: () => context.push(AppConstants.routeAiImportReview(job.id)),
        child: const Text('Review'),
      ),
      AiImportJobState.failed when onDismiss != null => FilledButton(
        key: Key('ai_import_job_dismiss_${job.id}'),
        style: tokens.secondaryButtonStyle.copyWith(
          minimumSize: const WidgetStatePropertyAll(Size(0, NomorexSizes.controlHeight)),
        ),
        onPressed: dismissing ? null : onDismiss,
        child: const Text('Dismiss'),
      ),
      _ => null,
    };

    return GroupableTile(
      key: Key('ai_import_job_${job.id}'),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyLarge),
                if (subtitle.isNotEmpty) Text(subtitle, style: muted),
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: 12), action],
        ],
      ),
    );
  }
}
