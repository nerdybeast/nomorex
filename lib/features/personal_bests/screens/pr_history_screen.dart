import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/personal_best.dart';
import '../providers/personal_bests_provider.dart';
import '../providers/pr_history_provider.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/pr_card.dart';
import '../utils/estimated_pr_label.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/weight_converter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../profile/providers/profile_provider.dart';

Future<void> _deletePr(BuildContext context, WidgetRef ref, PersonalBest pr, String unit) async {
  final confirmed = await showConfirmDialog(
    context,
    title: 'Delete personal best?',
    message: 'This removes the ${formatWeightForPreference(pr.weightKg, unit)} × '
        '${pr.reps == 1 ? '1 rep' : '${pr.reps} reps'} entry from ${formatDate(pr.date)}.',
    confirmLabel: 'Delete',
  );
  if (!confirmed) return;
  await ref.read(personalBestsProvider.notifier).deletePr(pr.id);
}

class PrHistoryScreen extends ConsumerWidget {
  const PrHistoryScreen({super.key, required this.exerciseId});
  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(prHistoryProvider(exerciseId));
    final unit = ref.watch(unitPreferenceProvider);
    final formula = ref.watch(oneRepMaxFormulaProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PR HISTORY'),
        actions: [
          IconButton(
            key: const Key('pr_history_add'),
            icon: const Icon(Icons.add),
            tooltip: 'Add personal best',
            onPressed: () => context.push(
              AppConstants.routeAddPrForExercise(
                exerciseId,
                weightKg: history.isNotEmpty ? history.first.weightKg : null,
                reps: history.isNotEmpty ? history.first.reps : null,
              ),
            ),
          ),
        ],
      ),
      body: history.isEmpty
          ? const Center(child: Text('No PR history found.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(history.first.exerciseName, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 16),
                for (final pr in history)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PrCard(
                      exerciseName: pr.exerciseName,
                      weightDisplay: formatWeightForPreference(pr.weightKg, unit),
                      reps: pr.reps,
                      dateDisplay: formatDate(pr.date),
                      notes: pr.notes,
                      estimatedOneRepMaxDisplay:
                          estimatedOneRepMaxLabel(pr, formula, unit),
                      onDelete: () => _deletePr(context, ref, pr, unit),
                    ),
                  ),
              ],
            ),
    );
  }
}
