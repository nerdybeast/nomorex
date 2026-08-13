import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/pr_card.dart';
import '../../../shared/widgets/program_instance_card.dart';
import '../../../shared/widgets/workout_in_progress_card.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/weight_converter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../personal_bests/providers/personal_bests_provider.dart';
import '../../programs/providers/program_instances_list_provider.dart';
import '../../programs/utils/program_progress.dart';
import '../../workouts/providers/in_progress_workouts_provider.dart';
import '../../profile/providers/profile_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prsAsync = ref.watch(personalBestsProvider);
    final instancesAsync = ref.watch(currentProgramInstancesProvider);
    final inProgressWorkoutsAsync = ref.watch(inProgressWorkoutsProvider);
    final unit = ref.watch(unitPreferenceProvider);
    final isRefreshing = inProgressWorkoutsAsync.isRefreshing ||
        instancesAsync.isRefreshing ||
        prsAsync.isRefreshing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('DASHBOARD'),
        actions: [
          IconButton(
            icon: isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: isRefreshing
                ? null
                : () {
                    ref.read(inProgressWorkoutsProvider.notifier).refresh();
                    ref.read(currentProgramInstancesProvider.notifier).refresh();
                    ref.read(personalBestsProvider.notifier).refresh();
                  },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () => context.push(AppConstants.routeProfile),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('WORKOUTS IN PROGRESS', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          inProgressWorkoutsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(
              'Failed to load workouts: $e',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            data: (workouts) {
              if (workouts.isEmpty) {
                return const Text('No workouts currently in progress.');
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final workout in workouts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: WorkoutInProgressCard(
                        title: workout.title,
                        statusDisplay: workout.status == 'paused'
                            ? 'Paused — started ${formatTime(workout.startedAt!)}'
                            : 'In progress — started ${formatTime(workout.startedAt!)}',
                        onTap: () => context.push(AppConstants.routeWorkoutDetail(workout.id)),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
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
