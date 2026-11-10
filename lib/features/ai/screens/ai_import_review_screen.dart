import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/ai_import_jobs_provider.dart';

/// Where "Review" leads for a finished import.
///
/// A placeholder until #86 builds the real preview, so the alert and the
/// Home card have a destination. Nothing reaches it in production: imports
/// are switched off until launch (#88).
class AiImportReviewScreen extends ConsumerWidget {
  const AiImportReviewScreen({super.key, required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = ref.watch(aiImportJobsProvider).value?.where((j) => j.id == jobId).firstOrNull;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Review import')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          job == null
              ? 'This import is no longer available.'
              : 'Your ${job.type ?? 'import'} is ready. Reviewing it in the app is coming soon.',
          key: const Key('ai_import_review_placeholder'),
          style: theme.textTheme.bodyLarge,
        ),
      ),
    );
  }
}
