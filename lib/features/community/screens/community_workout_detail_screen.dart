import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/copy_errors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/owner_name.dart';
import '../../../core/utils/weight_converter.dart';
import '../../../shared/widgets/set_pr_link.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../../workouts/models/workout_exercise.dart';
import '../../workouts/models/workout_set.dart';
import '../../workouts/providers/one_rep_max_provider.dart';
import '../../workouts/providers/workout_copy_count_provider.dart';
import '../../workouts/providers/workouts_provider.dart';
import '../../workouts/utils/set_resolver.dart';
import '../../../shared/models/one_rep_max.dart';
import '../providers/community_workout_detail_provider.dart';

class CommunityWorkoutDetailScreen extends ConsumerWidget {
  const CommunityWorkoutDetailScreen({super.key, required this.workoutId});
  final String workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(communityWorkoutDetailProvider(workoutId));
    final unit = ref.watch(unitPreferenceProvider);
    // The workout belongs to someone else, but its percentages are resolved
    // against the *viewer's* 1RMs on purpose — that's what makes this screen a
    // preview of "what would this session cost me" rather than a transcript of
    // what it cost its author.
    final maxes = ref.watch(oneRepMaxProvider).asData?.value ?? const {};
    final maxesByName = ref.watch(oneRepMaxByNameProvider).asData?.value ?? const {};
    final colorScheme = Theme.of(context).colorScheme;
    final viewerId = ref.watch(currentAuthUserProvider)?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(child: _Badge('Read only')),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e', style: TextStyle(color: colorScheme.error)),
        ),
        data: (workout) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(workout.title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
              'by ${ownerDisplayName(workout.ownerDisplayName)} · ${formatDate(workout.date)}',
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
            if (workout.notes != null && workout.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(workout.notes!),
            ],
            // Saving/starting someone else's workout makes a private copy;
            // there's nothing to copy from your own (FR-018).
            if (viewerId != null && workout.userId != viewerId) ...[
              const SizedBox(height: 16),
              _CopyActions(workoutId: workout.id),
            ],
            const SizedBox(height: 16),
            for (final ex in workout.exercises)
              _ExerciseCard(
                exercise: ex,
                oneRepMaxes: maxes,
                oneRepMaxesByName: maxesByName,
                unit: unit,
              ),
          ],
        ),
      ),
    );
  }
}

/// "Start workout" / "Save to my workouts". Both make a private copy in the
/// viewer's own workouts (Start also opens a session on it); this screen stays
/// a read-only preview of the original.
class _CopyActions extends ConsumerStatefulWidget {
  const _CopyActions({required this.workoutId});
  final String workoutId;

  @override
  ConsumerState<_CopyActions> createState() => _CopyActionsState();
}

class _CopyActionsState extends ConsumerState<_CopyActions> with AutomaticKeepAliveClientMixin {
  bool _busy = false;

  /// The SnackBar this screen is currently showing, if any. It lives on the
  /// app-wide ScaffoldMessenger, so without this it would follow the user back
  /// to the list; the PopScope in [build] closes it when the screen is popped.
  /// (Not from dispose(): that also runs while the whole app tree is torn
  /// down, when the ScaffoldMessenger itself is going away.)
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _snackBar;

  // Keep the buttons — and so the PopScope — alive while they're scrolled out
  // of the ListView.
  @override
  bool get wantKeepAlive => true;

  void _showSnackBar(ScaffoldMessengerState messenger, SnackBar snackBar) {
    // Once the screen is gone there's nothing left to close it, so only track
    // (and only let persist) SnackBars shown while it's still here.
    if (!mounted) {
      messenger.showSnackBar(snackBar);
      return;
    }
    // Ours must be the current SnackBar for close() to apply to it.
    messenger.removeCurrentSnackBar();
    final controller = messenger.showSnackBar(snackBar);
    _snackBar = controller;
    controller.closed.then((_) {
      if (identical(_snackBar, controller)) _snackBar = null;
    });
  }

  Future<void> _copy({required bool start}) => _run(
    start: start,
    notifier: ref.read(workoutsProvider.notifier),
    router: GoRouter.of(context),
    messenger: ScaffoldMessenger.of(context),
  );

  // Everything the SnackBar actions use is captured up front: a save can
  // finish after the user has left the screen, so View/Retry must never reach
  // for this State's context.
  Future<void> _run({
    required bool start,
    required WorkoutsNotifier notifier,
    required GoRouter router,
    required ScaffoldMessengerState messenger,
  }) async {
    if (mounted) setState(() => _busy = true);
    try {
      final newId = await notifier.saveCommunityWorkout(widget.workoutId, start: start);
      if (start) {
        // Don't yank the user somewhere if they've already left this screen.
        if (mounted) router.push(AppConstants.routeWorkoutDetail(newId));
      } else {
        _showSnackBar(
          messenger,
          SnackBar(
            content: const Text('Saved to your workouts'),
            // An action makes a SnackBar persist by default; this is a
            // confirmation, so let it time out like any other.
            persist: false,
            action: SnackBarAction(
              label: 'View',
              onPressed: () => router.push(AppConstants.routeWorkoutDetail(newId)),
            ),
          ),
        );
      }
    } catch (e) {
      _showSnackBar(
        messenger,
        SnackBar(
          content: Text(copyErrorMessage(e)),
          // Keep Retry on screen while the user is here; leaving closes it.
          persist: mounted,
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () =>
                _run(start: start, notifier: notifier, router: router, messenger: messenger),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final tokens = Theme.of(context).extension<NomorexTokens>();
    final copies = ref.watch(workoutCopyCountProvider(widget.workoutId)).asData?.value ?? 0;
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _snackBar?.close();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            key: const Key('community_workout_start'),
            onPressed: _busy ? null : () => _copy(start: true),
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: const Text('Start workout'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const Key('community_workout_save'),
            style: tokens?.secondaryButtonStyle,
            onPressed: _busy ? null : () => _copy(start: false),
            icon: const Icon(Icons.bookmark_add_outlined),
            label: const Text('Save to my workouts'),
          ),
          if (copies > 0) ...[
            const SizedBox(height: 6),
            Text(
              copies == 1 ? "You've saved this once" : "You've saved this $copies times",
              key: const Key('community_workout_saved_hint'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.oneRepMaxes,
    required this.oneRepMaxesByName,
    required this.unit,
  });

  final WorkoutExercise exercise;
  final Map<String, OneRepMax> oneRepMaxes;
  final Map<String, OneRepMax> oneRepMaxesByName;
  final String unit;

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
                child: Text(exercise.notes!, style: Theme.of(context).textTheme.bodySmall),
              ),
            const SizedBox(height: 4),
            for (final s in exercise.sets)
              _SetRow(
                set: s,
                exercise: exercise,
                oneRepMaxes: oneRepMaxes,
                oneRepMaxesByName: oneRepMaxesByName,
                unit: unit,
              ),
          ],
        ),
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.set,
    required this.exercise,
    required this.oneRepMaxes,
    required this.oneRepMaxesByName,
    required this.unit,
  });

  final WorkoutSet set;
  final WorkoutExercise exercise;
  final Map<String, OneRepMax> oneRepMaxes;
  final Map<String, OneRepMax> oneRepMaxesByName;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final reps = '${set.targetReps ?? '-'} reps';

    // Absolute sets are the same load for everyone, so they render plainly —
    // the accent color below is reserved for weights derived from the
    // viewer's own 1RM, which is what makes this a personalized preview.
    if (set.weightMode != 'percentage') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text('$reps · ${formatWeightForPreference(set.absoluteWeightKg ?? 0, unit)}'),
      );
    }

    final basisId = resolveBasisExerciseId(set, exercise);
    final basisName = set.basisExerciseName ?? exercise.exerciseName;
    final oneRepMax = lookupOneRepMax(
      basisExerciseId: basisId,
      basisExerciseName: basisName,
      byExerciseId: oneRepMaxes,
      byExerciseName: oneRepMaxesByName,
    );
    final resolvedKg = resolveSetWeightKg(
      weightMode: set.weightMode,
      percentage: set.percentage,
      absoluteWeightKg: set.absoluteWeightKg,
      oneRepMaxKg: oneRepMax?.kg,
    );

    // "70% 1RM" normally, but "75% of Clean & Jerk" when the set is programmed
    // against a different lift — otherwise the resolved weight beside it looks
    // wrong for the exercise it's filed under.
    final basisLabel = set.basisExerciseId != null ? 'of $basisName' : '1RM';
    final target = '$reps · ${set.percentage?.toStringAsFixed(0)}% $basisLabel · ';

    final baseStyle = DefaultTextStyle.of(context).style;
    final accent = Theme.of(context).extension<NomorexTokens>()?.info;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text.rich(
        TextSpan(
          style: baseStyle,
          children: [
            TextSpan(text: target),
            if (resolvedKg != null)
              TextSpan(
                text: formatResolvedWeight(resolvedKg, unit,
                    estimated: oneRepMax?.isEstimated ?? false),
                style: baseStyle.copyWith(color: accent),
              )
            else
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: SetPrLink(
                  exerciseId: basisId,
                  exerciseName: basisName,
                  style: baseStyle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
