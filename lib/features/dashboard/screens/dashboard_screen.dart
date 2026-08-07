import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/pr_card.dart';
import '../../../core/utils/weight_converter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../personal_bests/providers/personal_bests_provider.dart';
import '../../auth/providers/auth_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prsAsync = ref.watch(personalBestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('DASHBOARD'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
        ],
      ),
      body: prsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Failed to load PRs: $e',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
        data: (allPrs) {
          final seen = <String>{};
          final prs = allPrs
              .where((pr) => seen.add(pr.exerciseId))
              .take(5)
              .toList();
          if (prs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No PRs yet.\nTap + to log your first personal best.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: prs.length,
            itemBuilder: (context, index) {
              final pr = prs[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: PrCard(
                  exerciseName: pr.exerciseName,
                  weightDisplay: formatWeightBoth(pr.weightKg),
                  reps: pr.reps,
                  dateDisplay: formatDate(pr.date),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
