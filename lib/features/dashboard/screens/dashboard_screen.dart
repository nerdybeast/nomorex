import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/dashboard_empty_state_card.dart';
import '../../../shared/widgets/pr_card.dart';
import '../../personal_bests/utils/estimated_pr_label.dart';
import '../../../shared/widgets/program_instance_card.dart';
import '../../../shared/widgets/recent_workout_card.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../shared/widgets/workout_in_progress_card.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/dark_theme.dart';
import '../../../core/utils/weight_converter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../personal_bests/providers/personal_bests_provider.dart';
import '../../programs/providers/program_instances_list_provider.dart';
import '../../programs/providers/programs_provider.dart';
import '../../programs/utils/program_progress.dart';
import '../../workouts/providers/finished_workouts_provider.dart';
import '../../workouts/providers/in_progress_workouts_provider.dart';
import '../../workouts/providers/workouts_provider.dart';
import '../../workouts/widgets/elapsed_timer.dart';
import '../../profile/providers/profile_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prsAsync = ref.watch(personalBestsProvider);
    final instancesAsync = ref.watch(currentProgramInstancesProvider);
    final inProgressWorkoutsAsync = ref.watch(inProgressWorkoutsProvider);
    final finishedWorkoutsAsync = ref.watch(finishedWorkoutsProvider);
    // Only read by the empty states below, to pick "create your first" vs
    // "browse". Not-yet-loaded counts as none, which is the safe default.
    final hasWorkouts =
        ref.watch(workoutsProvider).asData?.value.isNotEmpty ?? false;
    final hasPrograms =
        ref.watch(programsProvider).asData?.value.isNotEmpty ?? false;
    final unit = ref.watch(unitPreferenceProvider);
    final formula = ref.watch(oneRepMaxFormulaProvider);
    final isRefreshing =
        inProgressWorkoutsAsync.isRefreshing ||
        instancesAsync.isRefreshing ||
        prsAsync.isRefreshing ||
        finishedWorkoutsAsync.isRefreshing;

    // A section that errored counts as settled/empty here so one unrelated
    // fetch failure can't hide the welcome message for an otherwise
    // brand-new user.
    bool isEmptyOrErrored<T>(AsyncValue<List<T>> asyncValue) {
      final data = asyncValue.value;
      if (data != null) return data.isEmpty;
      return asyncValue.hasError;
    }

    final sections = [
      inProgressWorkoutsAsync,
      instancesAsync,
      prsAsync,
      finishedWorkoutsAsync,
    ];
    final allSettled = sections.every((s) => s.hasValue || s.hasError);
    final showWelcome = allSettled && sections.every(isEmptyOrErrored);

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
                    ref
                        .read(currentProgramInstancesProvider.notifier)
                        .refresh();
                    ref.read(personalBestsProvider.notifier).refresh();
                    ref.read(finishedWorkoutsProvider.notifier).refresh();
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
        padding: shellListPadding(context),
        children: [
          if (showWelcome) ...[
            const _DashboardWelcomeBanner(),
            const SizedBox(height: 24),
          ],
          Text(
            'WORKOUTS IN PROGRESS',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          inProgressWorkoutsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(
              'Failed to load workouts: $e',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            data: (workouts) {
              if (workouts.isEmpty) {
                return DashboardEmptyStateCard(
                  icon: Icons.fitness_center_outlined,
                  title: 'No workouts currently in progress.',
                  message: hasWorkouts
                      ? 'Start one of your workouts to see it here while it\'s active.'
                      : 'Create a workout to see it here while it\'s active.',
                  ctaLabel: hasWorkouts
                      ? 'Browse workouts'
                      : 'Log your first workout',
                  onCta: () => hasWorkouts
                      ? context.go(AppConstants.routeWorkouts)
                      : context.push(AppConstants.routeWorkoutNew),
                );
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
                            ? 'Paused'
                            : 'In progress',
                        // Ticks live for an in-progress workout and renders
                        // frozen for a paused one — ElapsedTimer handles both.
                        statusTrailing: ElapsedTimer(
                          startedAt: workout.startedAt!,
                          totalPausedSeconds: workout.totalPausedSeconds,
                          pausedAt: workout.pausedAt,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                        onTap: () => context.push(
                          AppConstants.routeWorkoutDetail(workout.id),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'CURRENT PROGRAMS',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          instancesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(
              'Failed to load programs: $e',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            data: (instances) {
              if (instances.isEmpty) {
                return DashboardEmptyStateCard(
                  icon: Icons.checklist_outlined,
                  title: 'No programs currently in progress.',
                  message: hasPrograms
                      ? 'Browse your programs to start one and track your progress.'
                      : 'Create a program to plan your training and track your progress.',
                  ctaLabel: hasPrograms
                      ? 'Browse programs'
                      : 'Create your first program',
                  onCta: () => hasPrograms
                      ? context.go(AppConstants.routePrograms)
                      : context.push(AppConstants.routeProgramNew),
                );
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
                        onTap: () => context.push(
                          AppConstants.routeProgramInstanceDetail(instance.id),
                        ),
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
                return DashboardEmptyStateCard(
                  icon: Icons.emoji_events_outlined,
                  title: 'No PRs yet.',
                  message:
                      'Log a personal best to start tracking your progress.',
                  ctaLabel: 'Log your first PR',
                  onCta: () => context.push(AppConstants.routeAddPr),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final pr in prs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: PrCard(
                        exerciseName: pr.exerciseName,
                        weightDisplay: formatWeightForPreference(
                          pr.weightKg,
                          unit,
                        ),
                        reps: pr.reps,
                        dateDisplay: formatDate(pr.date),
                        notes: pr.notes,
                        notesMaxLines: 2,
                        estimatedOneRepMaxDisplay: estimatedOneRepMaxLabel(
                          pr,
                          formula,
                          unit,
                        ),
                        onTap: () => context.push(
                          AppConstants.routePrHistory(pr.exerciseId),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'RECENT WORKOUTS',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          finishedWorkoutsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(
              'Failed to load workouts: $e',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            data: (allFinished) {
              final recent = allFinished.take(5).toList();
              if (recent.isEmpty) {
                return const DashboardEmptyStateCard(
                  icon: Icons.history,
                  title: 'No completed workouts yet.',
                  message: "Finish a workout and it'll show up here.",
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final workout in recent)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: RecentWorkoutCard(
                        title: workout.title,
                        completedDisplay:
                            'Completed ${formatDate(workout.finishedAt!.toLocal())}',
                        onTap: () => context.push(
                          AppConstants.routeWorkoutDetail(workout.id),
                        ),
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

/// Shown above the section list only when the user has no data anywhere on
/// the dashboard yet, so a brand-new sign-in doesn't read as 4 stacked
/// empty sections with no framing.
class _DashboardWelcomeBanner extends StatelessWidget {
  const _DashboardWelcomeBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final overline = theme.extension<NomorexDarkTokens>()?.overline;
    return Card(
      color: colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colorScheme.primary),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.flag_outlined, color: colorScheme.primary, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('GET STARTED', style: overline),
                  const SizedBox(height: 4),
                  Text(
                    'Welcome to NoMoreX',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Log a workout, hit a new PR, or start a program — your '
                    'dashboard will fill in as you go.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
