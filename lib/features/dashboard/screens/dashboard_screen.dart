import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/pr_card.dart';
import '../../../shared/widgets/program_instance_card.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/weight_converter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../personal_bests/providers/personal_bests_provider.dart';
import '../../programs/providers/program_instances_list_provider.dart';
import '../../programs/utils/program_progress.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/providers/profile_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prsAsync = ref.watch(personalBestsProvider);
    final instancesAsync = ref.watch(currentProgramInstancesProvider);
    final unit = ref.watch(unitPreferenceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('DASHBOARD'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () => context.push(AppConstants.routeProfile),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('CURRENT PROGRAMS', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          instancesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(
              'Failed to load programs: $e',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            data: (instances) {
              if (instances.isEmpty) {
                return const Text('No programs currently in progress.');
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final instance in instances)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ProgramInstanceCard(
                        programName: instance.programName ?? 'Program',
                        statusDisplay: isProgramUpcoming(instance.startedAt)
                            ? 'Upcoming — starts ${formatDate(instance.startedAt)}'
                            : 'In progress — started ${formatDate(instance.startedAt)}',
                        onTap: () =>
                            context.push(AppConstants.routeProgramInstanceDetail(instance.id)),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text('RECENT PRS', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          prsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(
              'Failed to load PRs: $e',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            data: (allPrs) {
              final seen = <String>{};
              final prs = allPrs
                  .where((pr) => seen.add(pr.exerciseId))
                  .take(5)
                  .toList();
              if (prs.isEmpty) {
                return const Text('No PRs yet.\nTap + to log your first personal best.');
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final pr in prs)
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
              );
            },
          ),
        ],
      ),
    );
  }
}
