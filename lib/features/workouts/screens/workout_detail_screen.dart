import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/number_stepper_field.dart';
import '../../../core/utils/rpe.dart';
import '../../../core/utils/percent_range.dart';
import '../../../core/utils/rep_range.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/weight_converter.dart';
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
        title: const Text('Workout'),
        actions: [
          if (showEditIcon)
            IconButton(
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
          padding: const EdgeInsets.all(16),
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
                onLogRpe: (setId, rpe) => notifier.logRpe(setId, rpe),
                onLogWeight: (setId, kg) => notifier.logWeight(setId, kg),
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
    required this.onLogRpe,
    required this.onLogWeight,
  });

  final WorkoutExercise exercise;
  final Map<String, OneRepMax> oneRepMaxes;
  final Map<String, OneRepMax> oneRepMaxesByName;
  final String unit;
  final bool interactive;
  final void Function(String setId, bool value)? onToggle;
  /// Logs (or with null, clears) the lifter's RPE for a set. Only offered
  /// while [interactive]; a finished session shows its logged RPE read-only.
  final void Function(String setId, double? rpe)? onLogRpe;
  /// Logs (or with null, clears) the weight used on an open-load set, the
  /// only kind with no prescribed load to go by. Same rules as [onLogRpe].
  final void Function(String setId, double? weightKg)? onLogWeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = NomorexTokens.of(context);
    final notes = exercise.notes;
    final done = exercise.sets.where((s) => s.completed).length;
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
                  '$done/${exercise.sets.length} sets',
                  style: tokens.eyebrow.copyWith(letterSpacing: 0),
                ),
            ],
          ),
        ),
      ),
      children: [for (final s in exercise.sets) _setTile(s)],
    );
  }

  Widget _setTile(WorkoutSet s) {
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
      onToggle: onToggle,
      onLogRpe: onLogRpe,
      onLogWeight: onLogWeight,
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
    required this.onToggle,
    required this.onLogRpe,
    required this.onLogWeight,
  });

  final WorkoutSet set;
  final String basisExerciseId;

  /// Display name for [basisExerciseId] — [SetPrLink] needs it to give the
  /// viewer their own copy of the lift when this workout belongs to someone
  /// else and the basis is one of that owner's custom exercises.
  final String basisExerciseName;
  final OneRepMax? oneRepMax;
  final String unit;
  final bool interactive;
  final void Function(String setId, bool value)? onToggle;
  /// Logs (or with null, clears) the lifter's RPE for a set. Only offered
  /// while [interactive]; a finished session shows its logged RPE read-only.
  final void Function(String setId, double? rpe)? onLogRpe;
  /// Logs (or with null, clears) the weight used on an open-load set, the
  /// only kind with no prescribed load to go by. Same rules as [onLogRpe].
  final void Function(String setId, double? weightKg)? onLogWeight;

  @override
  Widget build(BuildContext context) {
    final resolved = resolveSetWeightRangeKg(
      weightMode: set.weightMode,
      percentage: set.percentage,
      percentageMax: set.percentageMax,
      absoluteWeightKg: set.absoluteWeightKg,
      oneRepMaxKg: oneRepMax?.kg,
    );
    final pct = formatPercentTarget(set.percentage, set.percentageMax);
    final rpeTarget = formatRpeTarget(set.rpeMin, set.rpeMax);
    final rpeSuffix = rpeTarget == null ? '' : ' · $rpeTarget';

    final basisSuffix =
        set.basisExerciseId != null ? ' of ${set.basisExerciseName ?? '1RM'}' : '';
    final colorScheme = Theme.of(context).colorScheme;
    final baseStyle = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(color: colorScheme.onSurfaceVariant);

    final Widget subtitle;
    if (isOpenLoad(set.weightMode)) {
      // No load to resolve, so no "Add PR" shortcut either.
      subtitle = Text('$kOpenLoadLabel$rpeSuffix');
    } else if (set.weightMode == 'percentage' && resolved == null) {
      subtitle = Text.rich(
        TextSpan(
          style: baseStyle,
          children: [
            TextSpan(text: '$pct$basisSuffix — '),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: SetPrLink(
                exerciseId: basisExerciseId,
                exerciseName: basisExerciseName,
                style: baseStyle,
              ),
            ),
            if (rpeTarget != null) TextSpan(text: rpeSuffix),
          ],
        ),
      );
    } else {
      final trailingText = set.weightMode == 'percentage'
          ? '$pct$basisSuffix · ${formatResolvedWeightRange(resolved!.low, resolved.high, unit, estimated: oneRepMax?.isEstimated ?? false)}'
          : formatWeightForPreference(resolved?.low ?? 0, unit);
      subtitle = Text('$trailingText$rpeSuffix');
    }

    // The whole row toggles the set. A completed set's reps drop to fg-2 but
    // the weight stays readable — no strikethrough.
    final tile = CheckboxListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      controlAffinity: ListTileControlAffinity.leading,
      value: set.completed,
      onChanged: interactive ? (v) => onToggle?.call(set.id, v ?? false) : null,
      title: Text(
        formatTargetReps(set.targetReps, set.targetRepsMax),
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: set.completed ? colorScheme.onSurfaceVariant : colorScheme.onSurface,
            ),
      ),
      subtitle: subtitle,
    );
    final rpe = _ActualRpe(set: set, interactive: interactive, onLog: onLogRpe);
    final weight = _ActualWeight(
      set: set,
      unit: unit,
      interactive: interactive,
      onLog: onLogWeight,
    );
    if (!rpe.isVisible && !weight.isVisible) return tile;
    // Beside the tile, not its `secondary`: a ListTile merges its children
    // into one semantics node, so a button inside it is announced as part of
    // the checkbox and can't be activated on its own by assistive tech.
    return Row(
      children: [
        Expanded(child: tile),
        if (weight.isVisible) weight,
        if (rpe.isVisible)
          Padding(padding: const EdgeInsets.only(right: 8), child: rpe),
      ],
    );
  }
}

/// The effort logged for a set. While the session is live it's a button
/// ("Log RPE", or "RPE 8" once logged) that opens [showRpeDialog]; afterwards
/// it's plain text, and absent when nothing was logged. Never pre-filled from
/// the set's target: an unlogged set stays unlogged.
class _ActualRpe extends StatelessWidget {
  const _ActualRpe({required this.set, required this.interactive, required this.onLog});

  final WorkoutSet set;
  final bool interactive;
  final void Function(String setId, double? rpe)? onLog;

  bool get _canLog => interactive && onLog != null;

  /// False when there's nothing to show: not loggable and nothing logged.
  bool get isVisible => _canLog || set.actualRpe != null;

  @override
  Widget build(BuildContext context) {
    final logged = set.actualRpe;
    final label = logged == null ? 'Log RPE' : 'RPE ${formatRpe(logged)}';
    if (!_canLog) return Text(label, key: Key('set_actual_rpe_${set.id}'));
    return TextButton(
      key: Key('set_actual_rpe_${set.id}'),
      onPressed: () async {
        // Start the stepper somewhere sensible, but save nothing until Save.
        final result = await showRpeDialog(
          context,
          logged: logged,
          start: logged ?? set.rpeMin ?? 7,
        );
        if (result != null) onLog!(set.id, result.rpe);
      },
      child: Text(label),
    );
  }
}

/// The weight used on an open-load set. Like [_ActualRpe]: a button ("Log
/// weight", or the logged weight) while the session is live, plain text
/// afterwards, absent when nothing was logged. Other sets have a prescribed
/// load, so they never show it.
class _ActualWeight extends StatelessWidget {
  const _ActualWeight({
    required this.set,
    required this.unit,
    required this.interactive,
    required this.onLog,
  });

  final WorkoutSet set;
  final String unit;
  final bool interactive;
  final void Function(String setId, double? weightKg)? onLog;

  bool get _canLog => interactive && onLog != null;

  bool get isVisible =>
      isOpenLoad(set.weightMode) && (_canLog || set.actualWeightKg != null);

  @override
  Widget build(BuildContext context) {
    final logged = set.actualWeightKg;
    final label =
        logged == null ? 'Log weight' : formatWeightForPreference(logged, unit);
    if (!_canLog) return Text(label, key: Key('set_actual_weight_${set.id}'));
    return TextButton(
      key: Key('set_actual_weight_${set.id}'),
      onPressed: () async {
        final result = await showWeightDialog(context, loggedKg: logged, unit: unit);
        if (result != null) onLog!(set.id, result.weightKg);
      },
      child: Text(label),
    );
  }
}

/// Asks for the weight used on a set, in the user's unit (kg when they show
/// both). Returns null on Cancel, `(weightKg: null)` on Clear (only offered
/// when [loggedKg] is set), and `(weightKg: value)` on Save.
Future<({double? weightKg})?> showWeightDialog(
  BuildContext context, {
  required double? loggedKg,
  required String unit,
}) {
  final dialogUnit = unit == 'lbs' ? 'lbs' : 'kg';
  var value = loggedKg == null
      ? 0.0
      : (dialogUnit == 'lbs' ? kgToLbs(loggedKg) : loggedKg);
  final tokens = Theme.of(context).extension<NomorexTokens>();
  return showDialog<({double? weightKg})>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Log weight'),
        content: NumberStepperField(
          key: const Key('log_weight_value'),
          label: 'Weight ($dialogUnit)',
          value: value,
          min: 0,
          step: dialogUnit == 'lbs' ? 5.0 : 2.5,
          decimals: 1,
          onChanged: (v) => setState(() => value = v),
          valueTextStyle: tokens?.stepperValue,
          valueDecoration: tokens?.stepperValueDecoration,
          decrementButtonStyle: tokens?.stepperDecrementStyle,
          incrementButtonStyle: tokens?.stepperIncrementStyle,
        ),
        actions: [
          if (loggedKg != null)
            TextButton(
              onPressed: () => Navigator.pop(ctx, (weightKg: null)),
              child: const Text('Clear'),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              (weightKg: dialogUnit == 'lbs' ? lbsToKg(value) : value),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

/// Asks for a set's RPE. Returns null on Cancel, `(rpe: null)` on Clear (only
/// offered when [logged] is set), and `(rpe: value)` on Save.
Future<({double? rpe})?> showRpeDialog(
  BuildContext context, {
  required double? logged,
  required double start,
}) {
  var value = start;
  final tokens = Theme.of(context).extension<NomorexTokens>();
  return showDialog<({double? rpe})>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Log RPE'),
        content: NumberStepperField(
          key: const Key('log_rpe_value'),
          label: 'RPE',
          value: value,
          min: kRpeMin,
          max: kRpeMax,
          step: kRpeStep,
          decimals: 1,
          onChanged: (v) => setState(() => value = v),
          valueTextStyle: tokens?.stepperValue,
          valueDecoration: tokens?.stepperValueDecoration,
          decrementButtonStyle: tokens?.stepperDecrementStyle,
          incrementButtonStyle: tokens?.stepperIncrementStyle,
        ),
        actions: [
          if (logged != null)
            TextButton(onPressed: () => Navigator.pop(ctx, (rpe: null)), child: const Text('Clear')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, (rpe: value)), child: const Text('Save')),
        ],
      ),
    ),
  );
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
