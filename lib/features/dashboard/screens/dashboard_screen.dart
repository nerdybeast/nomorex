import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../ai/providers/ai_import_jobs_provider.dart';
import '../../ai/widgets/ai_import_jobs_section.dart';
import '../../../shared/widgets/list_group.dart';
import '../../../shared/widgets/pr_card.dart';
import '../../personal_bests/utils/all_time_best.dart';
import '../../personal_bests/utils/estimated_pr_label.dart';
import '../../personal_bests/utils/recent_prs.dart';
import '../../../shared/widgets/program_instance_card.dart';
import '../../../shared/widgets/recent_workout_card.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../shared/widgets/workout_in_progress_card.dart';
import '../widgets/getting_started.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/weight_converter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../personal_bests/providers/personal_bests_provider.dart';
import '../../programs/providers/program_instances_list_provider.dart';
import '../../programs/providers/programs_provider.dart';
import '../../programs/utils/program_progress.dart';
import '../../programs/widgets/program_stats_chips.dart';
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
    // Only read by the empty rows and getting started, to pick "new" vs
    // "browse"/"start". Not-yet-loaded counts as none, the safe default.
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
    // fetch failure can't hide getting started from an otherwise brand-new
    // user.
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
    final firstRun = allSettled && sections.every(isEmptyOrErrored);
    // Two or more failures is the connection, not one query: one notice for
    // the page beats a column of identical errors.
    final pageFailed = sections.where((s) => s.hasError).length >= 2;
    // A section shows unless getting started has replaced it (a first run
    // keeps only a failed section, so its error isn't hidden) or the page
    // notice already covers its failure.
    bool shows(AsyncValue<Object?> s) {
      if (pageFailed && s.hasError) return false;
      return !firstRun || s.hasError;
    }

    void refreshAll() {
      ref.read(inProgressWorkoutsProvider.notifier).refresh();
      ref.read(currentProgramInstancesProvider.notifier).refresh();
      ref.read(personalBestsProvider.notifier).refresh();
      ref.read(finishedWorkoutsProvider.notifier).refresh();
      ref.invalidate(aiImportJobsProvider);
    }

    // A failed section's row. Checked before `when()`: while Riverpod retries
    // a failed load the state is a reload that still holds the error, and
    // `when()` would show a spinner until the retries run out.
    final workoutsFailure = _LoadFailure(
      message: "Couldn't load workouts in progress",
      retrying: inProgressWorkoutsAsync.retrying,
      onRetry: () => ref.read(inProgressWorkoutsProvider.notifier).refresh(),
    );
    final runsFailure = _LoadFailure(
      message: "Couldn't load current programs",
      retrying: instancesAsync.retrying,
      onRetry: () => ref.read(currentProgramInstancesProvider.notifier).refresh(),
    );
    final prsFailure = _LoadFailure(
      message: "Couldn't load PRs",
      retrying: prsAsync.retrying,
      onRetry: () => ref.read(personalBestsProvider.notifier).refresh(),
    );
    final historyFailure = _LoadFailure(
      message: "Couldn't load recent workouts",
      retrying: finishedWorkoutsAsync.retrying,
      onRetry: () => ref.read(finishedWorkoutsProvider.notifier).refresh(),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
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
            onPressed: isRefreshing ? null : refreshAll,
          ),
          // On wide layouts the sidebar's account card opens Profile.
          if (isMobile(context))
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
          if (pageFailed) ...[
            _LoadFailure(
              key: const Key('dashboard_load_failure'),
              message: "Couldn't load Home",
              retrying: sections.any((s) => s.retrying),
              onRetry: refreshAll,
            ),
            const SizedBox(height: 24),
          ],
          // Until every section has answered, a page with nothing to show yet
          // could still turn out to be a first run: one spinner, rather than
          // four labelled ones that getting started then replaces.
          if (!allSettled && !sections.any((s) => s.value?.isNotEmpty ?? false))
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (firstRun) ...[
              GettingStarted(hasPrograms: hasPrograms),
              const SizedBox(height: 32),
            ],
            // Empty unless the user has an import running, ready or failed.
            const AiImportJobsSection(),
            if (shows(inProgressWorkoutsAsync)) ...[
              const _SectionLabel('Workouts in progress'),
              const SizedBox(height: 8),
              if (inProgressWorkoutsAsync.retrying) workoutsFailure else inProgressWorkoutsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => workoutsFailure,
                data: (workouts) {
                  if (workouts.isEmpty) {
                    return _EmptySection(
                      key: const Key('dashboard_empty_workouts'),
                      message: 'Nothing in progress',
                      actionLabel: hasWorkouts ? 'Browse workouts' : 'New workout',
                      onTap: () => hasWorkouts
                          ? context.go(AppConstants.routeWorkouts)
                          : context.push(AppConstants.routeWorkoutNew),
                    );
                  }
                  return ListGroup(
                    children: [
                      for (final workout in workouts)
                        WorkoutInProgressCard(
                            title: workout.title,
                            statusDisplay: workout.status == 'paused'
                                ? 'Paused'
                                : 'In progress',
                            isLive: workout.status != 'paused',
                            programLabel: workout.programName ?? 'Standalone',
                            isStandalone: workout.programName == null,
                            // Ticks live for an in-progress workout and renders
                            // frozen for a paused one — ElapsedTimer handles both.
                            statusTrailing: ElapsedTimer(
                              startedAt: workout.startedAt!,
                              totalPausedSeconds: workout.totalPausedSeconds,
                              pausedAt: workout.pausedAt,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: NomorexTokens.of(context).palette.fg1,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                            ),
                            onTap: () => context.push(
                              AppConstants.routeWorkoutDetail(workout.id),
                            ),
                          ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
            if (shows(instancesAsync)) ...[
              const _SectionLabel('Current programs'),
              const SizedBox(height: 8),
              if (instancesAsync.retrying) runsFailure else instancesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => runsFailure,
                data: (instances) {
                  if (instances.isEmpty) {
                    return _EmptySection(
                      key: const Key('dashboard_empty_programs'),
                      message: 'No program started',
                      actionLabel: hasPrograms ? 'Start a program' : 'New program',
                      onTap: () => hasPrograms
                          ? context.go(AppConstants.routePrograms)
                          : context.push(AppConstants.routeProgramNew),
                    );
                  }
                  return ListGroup(
                    children: [
                      for (final instance in instances)
                        ProgramInstanceCard(
                            programName: instance.programName ?? 'Program',
                            statusDisplay: isProgramUpcoming(instance.startedAt)
                                ? 'Upcoming — starts ${formatDate(instance.startedAt)}'
                                : 'In progress — started ${formatDate(instance.startedAt)}',
                            chips: [
                              if (instance.stats case final stats?) ...programStatsChips(stats),
                            ],
                            onTap: () => context.push(
                              AppConstants.routeProgramInstanceDetail(instance.id),
                            ),
                          ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
            if (shows(prsAsync)) ...[
              const _SectionLabel('Recent PRs'),
              const SizedBox(height: 8),
              if (prsAsync.retrying) prsFailure else prsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => prsFailure,
                data: (allPrs) {
                  // Same "current entry" as My PRs: latest by PR date, so a
                  // back-filled old PR doesn't jump to the top.
                  final prs = latestPrPerExercise(allPrs).take(5).toList();
                  if (prs.isEmpty) {
                    return _EmptySection(
                      key: const Key('dashboard_empty_prs'),
                      message: 'No PRs yet',
                      actionLabel: 'Add a PR',
                      onTap: () => context.push(AppConstants.routeAddPr),
                    );
                  }
                  return ListGroup(
                    children: [
                      for (final pr in prs)
                        PrCard(
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
                            // The badge only marks the shown entry when it is
                            // also the lift's all-time best (same rule as PR
                            // history), so an older, heavier PR suppresses it.
                            allTimeBest: allTimeBest(
                                  [
                                    for (final other in allPrs)
                                      if (other.exerciseId == pr.exerciseId) other,
                                  ],
                                  formula,
                                )?.id ==
                                pr.id,
                            onTap: () => context.push(
                              AppConstants.routePrHistory(pr.exerciseId),
                            ),
                          ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
            if (shows(finishedWorkoutsAsync)) ...[
              const _SectionLabel('Recent workouts'),
              const SizedBox(height: 8),
              if (finishedWorkoutsAsync.retrying) historyFailure else finishedWorkoutsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => historyFailure,
                data: (allFinished) {
                  final recent = allFinished.take(5).toList();
                  if (recent.isEmpty) {
                    return const _EmptySection(
                      key: Key('dashboard_empty_history'),
                      message: 'Finished workouts show up here',
                    );
                  }
                  return ListGroup(
                    children: [
                      for (final workout in recent)
                        RecentWorkoutCard(
                            title: workout.title,
                            completedDisplay:
                                'Completed ${formatDate(workout.finishedAt!.toLocal())}',
                            programLabel: workout.programName ?? 'Standalone',
                            isStandalone: workout.programName == null,
                            onTap: () => context.push(
                              AppConstants.routeWorkoutDetail(workout.id),
                            ),
                          ),
                    ],
                  );
                },
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// A section's eyebrow label: mono caps in fg-3, above its rows.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    // A heading for screen readers, so they can jump section to section.
    return Semantics(
      header: true,
      child: Text(label.toUpperCase(), style: NomorexTokens.of(context).eyebrow),
    );
  }
}

/// A section with nothing in it yet: one line in the section's own group, so
/// it takes a row's height rather than a card's. With an action, the whole row
/// is the button.
class _EmptySection extends StatelessWidget {
  const _EmptySection({super.key, required this.message, this.actionLabel, this.onTap})
    : assert((actionLabel == null) == (onTap == null));

  final String message;
  final String? actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    final label = actionLabel;
    final row = GroupableTile(
      onTap: onTap,
      // 14 rather than the row default 12, so the row is a 48px target.
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(child: Text(message, style: tokens.bodySmall.copyWith(color: palette.fg3))),
          if (label != null) ...[
            const SizedBox(width: 12),
            Text(label, style: theme.textTheme.titleSmall?.copyWith(color: palette.fg1)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: tokens.fg3, size: 20),
          ],
        ],
      ),
    );
    // One node for the row, so a screen reader reads "Nothing in progress,
    // New workout" as one button and can activate it.
    return ListGroup(
      children: [label == null ? row : MergeSemantics(child: Semantics(button: true, child: row))],
    );
  }
}

/// A section, or the whole page, that failed to load: what failed and a way to
/// try again, never the raw error (which names the backend and means nothing
/// to a lifter). Riverpod retries a failed load on its own for a while; the
/// row says so, and Retry skips the wait.
class _LoadFailure extends StatelessWidget {
  const _LoadFailure({super.key, required this.message, required this.retrying, required this.onRetry});

  final String message;
  final bool retrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = NomorexTokens.of(context);
    return ListGroup(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          child: Row(
            children: [
              Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.error)),
                    Text(
                      retrying ? 'Trying again…' : 'Check your connection, then retry.',
                      style: tokens.bodySmall.copyWith(color: tokens.fg3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ],
    );
  }
}
