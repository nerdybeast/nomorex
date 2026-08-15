import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/dark_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/weight_converter.dart';
import '../../../shared/widgets/set_pr_link.dart';
import '../../profile/providers/profile_provider.dart';
import '../models/workout.dart';
import '../models/workout_exercise.dart';
import '../models/workout_set.dart';
import '../providers/one_rep_max_provider.dart';
import '../providers/workout_detail_provider.dart';
import '../providers/workout_group_history_provider.dart';
import '../utils/set_resolver.dart';
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
    final showEditIcon = workout == null || workout.status == 'not_started';
    final isBusy = detail.isLoading;
    final hasHistory =
        workout != null && ref.watch(groupHasFinishedHistoryProvider(workout.workoutGroupId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('WORKOUT'),
        actions: [
          if (showEditIcon)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push(AppConstants.routeWorkoutEdit(workoutId)),
            ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: colorScheme.error))),
        data: (workout) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(workout.title, style: Theme.of(context).textTheme.headlineSmall),
            Text(formatDate(workout.date)),
            if (workout.notes != null && workout.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(workout.notes!),
            ],
            const SizedBox(height: 4),
            Text(
              'Last edited ${formatDate(workout.updatedAt)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
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
        return ElapsedTimer(
          startedAt: workout.startedAt!,
          totalPausedSeconds: workout.totalPausedSeconds,
          pausedAt: workout.pausedAt,
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
            const SizedBox(height: 16),
            _FinishedActions(workout: workout, notifier: notifier),
          ],
        );
      default: // 'not_started'
        if (hasHistory) {
          return _NotStartedWithHistoryActions(
            workoutGroupId: workout.workoutGroupId,
            notifier: notifier,
          );
        }
        return FilledButton(
          onPressed: isBusy ? null : () => notifier.startWorkout(),
          child: const Text('Start Workout'),
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
    final tokens = Theme.of(context).extension<NomorexDarkTokens>();
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
      primaryLabel: 'Do This Workout Again',
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
      primaryLabel: 'Do This Workout Again',
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
          child: TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.blue),
            onPressed: () =>
                context.push(AppConstants.routeWorkoutHistoryFiltered(workoutGroupId)),
            child: const Text('View History'),
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
  });

  final WorkoutExercise exercise;
  final Map<String, double> oneRepMaxes;
  final Map<String, double> oneRepMaxesByName;
  final String unit;
  final bool interactive;
  final void Function(String setId, bool value)? onToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exercise.exerciseName, style: Theme.of(context).textTheme.titleMedium),
            if (exercise.notes != null && exercise.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(exercise.notes!,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            const SizedBox(height: 4),
            for (final s in exercise.sets) _setTile(s),
          ],
        ),
      ),
    );
  }

  Widget _setTile(WorkoutSet s) {
    final basisId = resolveBasisExerciseId(s, exercise);
    final basisName = s.basisExerciseName ?? exercise.exerciseName;
    return _SetTile(
      set: s,
      basisExerciseId: basisId,
      basisExerciseName: basisName,
      oneRepMaxKg: lookupOneRepMaxKg(
        basisExerciseId: basisId,
        basisExerciseName: basisName,
        byExerciseId: oneRepMaxes,
        byExerciseName: oneRepMaxesByName,
      ),
      unit: unit,
      interactive: interactive,
      onToggle: onToggle,
    );
  }
}

class _SetTile extends StatelessWidget {
  const _SetTile({
    required this.set,
    required this.basisExerciseId,
    required this.basisExerciseName,
    required this.oneRepMaxKg,
    required this.unit,
    required this.interactive,
    required this.onToggle,
  });

  final WorkoutSet set;
  final String basisExerciseId;

  /// Display name for [basisExerciseId] — [SetPrLink] needs it to give the
  /// viewer their own copy of the lift when this workout belongs to someone
  /// else and the basis is one of that owner's custom exercises.
  final String basisExerciseName;
  final double? oneRepMaxKg;
  final String unit;
  final bool interactive;
  final void Function(String setId, bool value)? onToggle;

  @override
  Widget build(BuildContext context) {
    final resolvedKg = resolveSetWeightKg(
      weightMode: set.weightMode,
      percentage: set.percentage,
      absoluteWeightKg: set.absoluteWeightKg,
      oneRepMaxKg: oneRepMaxKg,
    );

    final basisSuffix =
        set.basisExerciseId != null ? ' of ${set.basisExerciseName ?? '1RM'}' : '';
    final colorScheme = Theme.of(context).colorScheme;
    final baseStyle = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(color: colorScheme.onSurfaceVariant);

    final Widget subtitle;
    if (set.weightMode == 'percentage' && resolvedKg == null) {
      subtitle = Text.rich(
        TextSpan(
          style: baseStyle,
          children: [
            TextSpan(text: '${set.percentage?.toStringAsFixed(0)}%$basisSuffix — '),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: SetPrLink(
                exerciseId: basisExerciseId,
                exerciseName: basisExerciseName,
                style: baseStyle,
              ),
            ),
          ],
        ),
      );
    } else {
      final trailingText = set.weightMode == 'percentage'
          ? '${set.percentage?.toStringAsFixed(0)}%$basisSuffix · ${formatWeightForPreference(resolvedKg!, unit)}'
          : formatWeightForPreference(resolvedKg ?? 0, unit);
      subtitle = Text(trailingText);
    }

    return CheckboxListTile(
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      value: set.completed,
      onChanged: interactive ? (v) => onToggle?.call(set.id, v ?? false) : null,
      title: Text('${set.targetReps ?? '-'} reps'),
      subtitle: subtitle,
    );
  }
}
