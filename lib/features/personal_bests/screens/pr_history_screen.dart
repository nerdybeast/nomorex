import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/personal_best.dart';
import '../providers/personal_bests_provider.dart';
import '../providers/pr_history_provider.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/pr_card.dart';
import '../utils/all_time_best.dart';
import '../utils/estimated_pr_label.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/one_rep_max_formula.dart';
import '../../../core/utils/weight_converter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../profile/providers/profile_provider.dart';
import '../../../shared/widgets/responsive_layout.dart';

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
    final best = allTimeBest(history, formula);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PR history'),
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
              padding: contentPadding(context),
              children: [
                Text(history.first.exerciseName, style: theme.textTheme.headlineMedium),
                const SizedBox(height: 16),
                Row(
                  key: const Key('pr_history_summary'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _BestSummary(
                        key: const Key('pr_history_current_best'),
                        label: 'CURRENT BEST',
                        pr: history.first,
                        unit: unit,
                        formula: formula,
                      ),
                    ),
                    if (best != null) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: _BestSummary(
                          key: const Key('pr_history_all_time_best'),
                          label: 'ALL-TIME BEST',
                          pr: best,
                          unit: unit,
                          formula: formula,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
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
                      allTimeBest: pr.id == best?.id,
                      onDelete: () => _deletePr(context, ref, pr, unit),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// One column of the summary above the history list: an eyebrow label, the
/// entry's weight, its reps, and its est. 1RM when it's a multi-rep entry.
class _BestSummary extends StatelessWidget {
  const _BestSummary({
    super.key,
    required this.label,
    required this.pr,
    required this.unit,
    required this.formula,
  });

  final String label;
  final PersonalBest pr;
  final String unit;
  final OneRepMaxFormula formula;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    final estimate = estimatedOneRepMaxLabel(pr, formula, unit);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: tokens.eyebrow),
        const SizedBox(height: 4),
        Text(
          formatWeightForPreference(pr.weightKg, unit),
          style: tokens.weightMd.copyWith(color: palette.fg1),
        ),
        Text(
          '${pr.reps == 1 ? '1 rep' : '${pr.reps} reps'} · ${formatDate(pr.date)}',
          style: theme.textTheme.bodySmall?.copyWith(color: palette.fg3),
        ),
        if (estimate != null)
          Text(
            estimate,
            style: tokens.weightSm.copyWith(color: palette.info),
          ),
      ],
    );
  }
}
