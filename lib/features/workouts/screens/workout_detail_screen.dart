import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/set_type_header.dart';
import '../../../shared/models/set_type.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/archived_pill.dart';
import '../../../shared/widgets/copied_from_badge.dart';
import '../../../shared/widgets/list_group.dart';
import '../../../shared/widgets/set_pr_link.dart';
import '../../../shared/widgets/summary_card.dart';
import '../../profile/providers/profile_provider.dart';
import '../models/workout.dart';
import '../models/workout_exercise.dart';
import '../models/workout_set.dart';
import '../providers/one_rep_max_provider.dart';
import '../providers/workout_detail_provider.dart';
import '../providers/workout_group_history_provider.dart';
import '../providers/workouts_provider.dart';
import '../utils/can_archive_workout.dart';
import '../utils/set_resolver.dart';
import '../../../shared/models/one_rep_max.dart';
import '../widgets/elapsed_timer.dart';
import '../widgets/live_set_row.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../shell/widgets/breadcrumb_title.dart';

class WorkoutDetailScreen extends ConsumerWidget {
  const WorkoutDetailScreen({super.key, required this.workoutId});
  final String workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(workoutDetailProvider(workoutId));
    final maxes = ref.watch(oneRepMaxProvider).asData?.value ?? const {};
    final maxesByName = ref.watch(oneRepMaxByNameProvider).asData?.value ?? const {};
    final unit = ref.watch(unitPreferenceProvider);
    final notifier = ref.read(workoutDetailProvider(workoutId).notifier);
    final colorScheme = Theme.of(context).colorScheme;
    final workout = detail.asData?.value;
    // An archived workout opens read-only: restoring is the only action.
    final showEditIcon =
        workout == null || (workout.status == 'not_started' && !workout.isArchived);
    // Unlike edit, Archive shouldn't be tappable before we've confirmed the
    // loaded workout isn't materialized from a program or mid-session.
    final showArchiveIcon = workout != null && canArchiveWorkout(workout);
    final isBusy = detail.isLoading;
    final hasHistory =
        workout != null && ref.watch(groupHasFinishedHistoryProvider(workout.workoutGroupId));

    return Scaffold(
      appBar: AppBar(
        title: BreadcrumbTitle(title: 'Workout', current: workout?.title),
        actions: [
          if (showEditIcon)
            IconButton(
              tooltip: 'Edit workout',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push(AppConstants.routeWorkoutEdit(workoutId)),
            ),
          if (showArchiveIcon)
            IconButton(
              key: const Key('workout_detail_archive'),
              icon: const Icon(Icons.archive_outlined),
              tooltip: 'Archive',
              onPressed: () async {
                await ref.read(workoutsProvider.notifier).archiveWorkout(workout);
                if (context.mounted) context.go(AppConstants.routeWorkouts);
              },
            ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: colorScheme.error))),
        data: (workout) => ListView(
          padding: contentPadding(context),
          children: [
            Text(workout.title, style: Theme.of(context).textTheme.headlineMedium),
            if (workout.isArchived) ...[
              const SizedBox(height: 8),
              const Align(alignment: Alignment.centerLeft, child: ArchivedPill()),
            ],
            if (workout.isCopy) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: CopiedFromBadge(
                  isCopy: true,
                  isImported: workout.isImported,
                  copiedFromUserId: workout.copiedFromUserId,
                  copiedFromDisplayName: workout.copiedFromDisplayName,
                  copiedFromSourceId: workout.copiedFromSourceId,
                ),
              ),
            ],
            if (workout.notes != null && workout.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(workout.notes!),
            ],
            const SizedBox(height: 8),
            _WorkoutFacts(workout: workout),
            const SizedBox(height: 24),
            if (workout.isArchived) ...[
              FilledButton(
                key: const Key('workout_detail_restore'),
                style: NomorexTokens.of(context).secondaryButtonStyle,
                onPressed: () => ref.read(workoutsProvider.notifier).restoreWorkout(workout),
                child: const Text('Restore'),
              ),
              const SizedBox(height: 16),
            ],
            _StatusSection(
              workout: workout,
              notifier: notifier,
              isBusy: isBusy,
              hasHistory: hasHistory,
            ),
            const SizedBox(height: 16),
            for (final ex in workout.exercises)
              _ExerciseCard(
                exercise: ex,
                oneRepMaxes: maxes,
                oneRepMaxesByName: maxesByName,
                unit: unit,
                interactive: workout.status == 'in_progress' || workout.status == 'paused',
                onToggle: (setId, value) => notifier.setCompleted(setId, value),
                onLog: (setId, logged) async {
                  try {
                    await notifier.logSet(
                      setId,
                      reps: logged.reps,
                      rpe: logged.rpe,
                      weightKg: logged.weightKg,
                      // Clearing the log leaves the set's done state alone.
                      complete: !logged.cleared,
                    );
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Couldn't save the log. Try again.")),
                      );
                    }
                  }
                },
              ),
            if (workout.status == 'in_progress' || workout.status == 'paused') ...[
              const SizedBox(height: 16),
              _StatusActions(
                workout: workout,
                notifier: notifier,
                isBusy: isBusy,
                workoutId: workoutId,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusSection extends StatelessWidget {
  const _StatusSection({
    required this.workout,
    required this.notifier,
    required this.isBusy,
    required this.hasHistory,
  });

  final Workout workout;
  final WorkoutDetailNotifier notifier;
  final bool isBusy;
  final bool hasHistory;

  @override
  Widget build(BuildContext context) {
    switch (workout.status) {
      case 'in_progress':
      case 'paused':
        final tokens = NomorexTokens.of(context);
        final palette = tokens.palette;
        final isLive = workout.status == 'in_progress';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // State line: the live dot is the only orange here.
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isLive ? palette.primary : palette.fg3,
                    boxShadow: isLive
                        ? [BoxShadow(color: palette.primarySubtle, spreadRadius: 3)]
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isLive ? 'In progress' : 'Paused',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: palette.fg2),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ElapsedTimer(
              startedAt: workout.startedAt!,
              totalPausedSeconds: workout.totalPausedSeconds,
              pausedAt: workout.pausedAt,
              maxScaledWidth: AppConstants.kWorkoutTimerMaxWidth,
              style: tokens.timer.copyWith(color: isLive ? palette.fg1 : palette.fg3),
            ),
          ],
        );
      case 'finished':
        final colorScheme = Theme.of(context).colorScheme;
        final labelStyle =
            Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Duration', style: labelStyle),
            ElapsedTimer(
              startedAt: workout.startedAt!,
              totalPausedSeconds: workout.totalPausedSeconds,
              finishedAt: workout.finishedAt,
            ),
            if (workout.sessionNotes != null && workout.sessionNotes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Notes', style: labelStyle),
              Text(workout.sessionNotes!),
            ],
            // Repeating would add a live session to an archived group.
            if (!workout.isArchived) ...[
              const SizedBox(height: 16),
              _FinishedActions(workout: workout, notifier: notifier),
            ],
          ],
        );
      default: // 'not_started'
        if (workout.isArchived) return const SizedBox.shrink();
        if (hasHistory) {
          return _NotStartedWithHistoryActions(
            workoutGroupId: workout.workoutGroupId,
            notifier: notifier,
          );
        }
        return FilledButton(
          onPressed: isBusy ? null : () => notifier.startWorkout(),
          child: const Text('Start workout'),
        );
    }
  }
}

// Pause/Resume + Finish, pinned below all the workout's content rather than
// next to the timer, so they're reachable at a consistent spot regardless of
// how many exercises/sets are in the workout.
class _StatusActions extends StatelessWidget {
  const _StatusActions({
    required this.workout,
    required this.notifier,
    required this.isBusy,
    required this.workoutId,
  });

  final Workout workout;
  final WorkoutDetailNotifier notifier;
  final bool isBusy;
  final String workoutId;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<NomorexTokens>();
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            style: tokens?.secondaryButtonStyle,
            onPressed: isBusy
                ? null
                : () => workout.status == 'in_progress'
                    ? notifier.pauseWorkout()
                    : notifier.resumeWorkout(),
            child: Text(workout.status == 'in_progress' ? 'Pause' : 'Resume'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: isBusy
                ? null
                : () async {
                    if (workout.status == 'in_progress') {
                      await notifier.pauseWorkout();
                    }
                    if (context.mounted) {
                      context.push(AppConstants.routeWorkoutFinish(workoutId));
                    }
                  },
            child: const Text('Finish'),
          ),
        ),
      ],
    );
  }
}

// "Do This Workout Again" (duplicates this workout, sharing its
// workoutGroupId, and immediately starts the copy), full-width like "Start
// Workout", plus a "View History" link below it — shown once a workout
// reaches 'finished'.
class _FinishedActions extends StatefulWidget {
  const _FinishedActions({required this.workout, required this.notifier});

  final Workout workout;
  final WorkoutDetailNotifier notifier;

  @override
  State<_FinishedActions> createState() => _FinishedActionsState();
}

class _FinishedActionsState extends State<_FinishedActions> {
  bool _isRepeating = false;

  Future<void> _repeat() async {
    setState(() => _isRepeating = true);
    try {
      final newWorkoutId = await widget.notifier.repeatWorkout();
      if (mounted) {
        context.push(AppConstants.routeWorkoutDetail(newWorkoutId));
      }
    } on StateError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isRepeating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PrimaryAndHistoryButtons(
      primaryLabel: 'Do this workout again',
      isBusy: _isRepeating,
      onPrimary: _isRepeating ? null : _repeat,
      workoutGroupId: widget.workout.workoutGroupId,
    );
  }
}

// A not-started workout whose group already has a finished completion:
// offers "Do This Workout Again" (really just starts *this* row — the
// eager "next instance" created when the prior completion finished, see
// WorkoutDetailNotifier.finishWorkout()) instead of plain "Start Workout",
// plus the same "View History" link.
class _NotStartedWithHistoryActions extends StatefulWidget {
  const _NotStartedWithHistoryActions({required this.workoutGroupId, required this.notifier});

  final String workoutGroupId;
  final WorkoutDetailNotifier notifier;

  @override
  State<_NotStartedWithHistoryActions> createState() => _NotStartedWithHistoryActionsState();
}

class _NotStartedWithHistoryActionsState extends State<_NotStartedWithHistoryActions> {
  bool _isStarting = false;

  Future<void> _start() async {
    setState(() => _isStarting = true);
    try {
      await widget.notifier.startWorkout();
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PrimaryAndHistoryButtons(
      primaryLabel: 'Do this workout again',
      isBusy: _isStarting,
      onPrimary: _isStarting ? null : _start,
      workoutGroupId: widget.workoutGroupId,
    );
  }
}

// Shared visual shell for "Do This Workout Again" (full-width, like "Start
// Workout") + a right-aligned blue "View History" link below it.
class _PrimaryAndHistoryButtons extends StatelessWidget {
  const _PrimaryAndHistoryButtons({
    required this.primaryLabel,
    required this.isBusy,
    required this.onPrimary,
    required this.workoutGroupId,
  });

  final String primaryLabel;
  final bool isBusy;
  final VoidCallback? onPrimary;
  final String workoutGroupId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: onPrimary,
          child: isBusy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(primaryLabel),
        ),
        Align(
          alignment: Alignment.centerRight,
          // Ghost button: neutral, no hardcoded color.
          child: TextButton(
            onPressed: () =>
                context.push(AppConstants.routeWorkoutHistoryFiltered(workoutGroupId)),
            child: const Text('View history'),
          ),
        ),
      ],
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.oneRepMaxes,
    required this.oneRepMaxesByName,
    required this.unit,
    required this.interactive,
    required this.onToggle,
    required this.onLog,
  });

  final WorkoutExercise exercise;
  final Map<String, OneRepMax> oneRepMaxes;
  final Map<String, OneRepMax> oneRepMaxesByName;
  final String unit;
  final bool interactive;
  final void Function(String setId, bool value)? onToggle;

  /// Saves what the lifter logged on a set (or clears it). Only offered while
  /// [interactive]; a finished session shows its logged values read-only.
  final void Function(String setId, LoggedSet logged)? onLog;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = NomorexTokens.of(context);
    final notes = exercise.notes;
    // Working sets only, so warm-ups don't inflate "2/4 sets"; an exercise
    // with no working sets counts them all.
    final counted = countedSets(exercise.sets, (s) => s.setType);
    final done = counted.where((s) => s.completed).length;
    // One list container per exercise: a bg-0 header (name, notes, a mono
    // "2/4 sets" count) over one row per set.
    return ListGroup(
      margin: const EdgeInsets.only(bottom: 12),
      header: ColoredBox(
        color: tokens.palette.bg0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.exerciseName,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (notes != null && notes.isNotEmpty)
                      Text(
                        notes,
                        style: theme.textTheme.bodySmall?.copyWith(color: tokens.fg3),
                      ),
                  ],
                ),
              ),
              if (exercise.sets.isNotEmpty)
                Text(
                  '$done/${counted.length} sets',
                  style: tokens.eyebrow.copyWith(letterSpacing: 0),
                ),
            ],
          ),
        ),
      ),
      // A WARM-UP / WORKING / COOL-DOWN header above each run of one type,
      // so every row's reps line up; none when all sets are working sets.
      children: withSetTypeHeaders(exercise.sets, typeOf: (s) => s.setType, row: (s) => _setTile(s, _setLabel(s))),
    );
  }

  /// "set 2", or "warm-up set 1": numbered within its type, as the run
  /// headers group them. Names the set's controls for screen readers.
  String _setLabel(WorkoutSet s) {
    final sameType = exercise.sets.where((o) => o.setType == s.setType).toList();
    final n = sameType.indexOf(s) + 1;
    return s.setType.isWorking ? 'set $n' : '${s.setType.label.toLowerCase()} set $n';
  }

  Widget _setTile(WorkoutSet s, String label) {
    final basisId = resolveBasisExerciseId(s, exercise);
    final basisName = s.basisExerciseName ?? exercise.exerciseName;
    return _SetTile(
      set: s,
      basisExerciseId: basisId,
      basisExerciseName: basisName,
      oneRepMax: lookupOneRepMax(
        basisExerciseId: basisId,
        basisExerciseName: basisName,
        byExerciseId: oneRepMaxes,
        byExerciseName: oneRepMaxesByName,
      ),
      unit: unit,
      interactive: interactive,
      setLabel: label,
      onToggle: onToggle,
      onLog: onLog,
    );
  }
}

class _SetTile extends StatelessWidget {
  const _SetTile({
    required this.set,
    required this.basisExerciseId,
    required this.basisExerciseName,
    required this.oneRepMax,
    required this.unit,
    required this.interactive,
    required this.setLabel,
    required this.onToggle,
    required this.onLog,
  });

  final WorkoutSet set;
  final String basisExerciseId;

  /// Display name for [basisExerciseId]. [SetPrLink] needs it to give the
  /// viewer their own copy of the lift when this workout belongs to someone
  /// else and the basis is one of that owner's custom exercises.
  final String basisExerciseName;
  final OneRepMax? oneRepMax;
  final String unit;
  final bool interactive;

  /// "set 2" or "warm-up set 1", for the controls' accessible names.
  final String setLabel;
  final void Function(String setId, bool value)? onToggle;
  final void Function(String setId, LoggedSet logged)? onLog;

  @override
  Widget build(BuildContext context) {
    final canLog = interactive && onLog != null;
    // The checkbox and the log chip are separate controls beside the set's
    // text, not inside a ListTile: a tile merges its children into one
    // semantics node, so a button inside it couldn't be reached on its own.
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 10),
      child: SetPrescriptionLines(
        set: set,
        oneRepMax: oneRepMax,
        basisExerciseId: basisExerciseId,
        basisExerciseName: basisExerciseName,
        unit: unit,
        done: set.completed,
        leading: SizedBox(
          width: 48,
          height: 40,
          child: Checkbox(
            key: ValueKey('set_done_${set.id}'),
            value: set.completed,
            semanticLabel: 'Done: $setLabel',
            onChanged: interactive ? (v) => onToggle?.call(set.id, v ?? false) : null,
          ),
        ),
        trailing: canLog || loggedSummary(set, unit) != null
            ? LogSetChip(
                set: set,
                unit: unit,
                setLabel: setLabel,
                onLog: canLog ? (logged) => onLog!(set.id, logged) : null,
              )
            : null,
      ),
    );
  }
}

/// Date, exercise count and last edit with their icons — the same facts the
/// Workouts list shows under each workout.
class _WorkoutFacts extends StatelessWidget {
  const _WorkoutFacts({required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        SummaryInfoChip(Icons.event_outlined, formatDate(workout.date)),
        SummaryInfoChip(Icons.list_alt_outlined, pluralize(workout.exercises.length, 'exercise')),
        SummaryInfoChip(Icons.update, 'Edited ${formatDate(workout.updatedAt)}'),
      ],
    );
  }
}
