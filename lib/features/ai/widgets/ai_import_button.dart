import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../providers/ai_import_intake_provider.dart';

/// The app-bar action into the import flow, on the Workouts and Programs
/// screens. Both lead to the same screen, which works out whether the files
/// hold a workout or a program.
///
/// Hidden while imports are switched off (`ai_import_limits.enabled`), and
/// while the limits haven't loaded or couldn't be, so the off switch also takes
/// the feature out of the app.
class AiImportButton extends ConsumerWidget {
  const AiImportButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(aiImportLimitsProvider.select((l) => l.value?.enabled ?? false));
    if (!enabled) return const SizedBox.shrink();
    return IconButton(
      key: const Key('ai_import_entry'),
      icon: const Icon(Icons.document_scanner_outlined),
      tooltip: 'Import from photo or PDF',
      onPressed: () => context.push(AppConstants.routeAiImport),
    );
  }
}
