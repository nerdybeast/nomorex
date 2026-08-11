import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pr_history_provider.dart';
import '../../../shared/widgets/pr_card.dart';
import '../../../core/utils/weight_converter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../profile/providers/profile_provider.dart';

class PrHistoryScreen extends ConsumerWidget {
  const PrHistoryScreen({super.key, required this.exerciseId});
  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(prHistoryProvider(exerciseId));
    final unit = ref.watch(unitPreferenceProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('PR HISTORY')),
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
                    ),
                  ),
              ],
            ),
    );
  }
}
