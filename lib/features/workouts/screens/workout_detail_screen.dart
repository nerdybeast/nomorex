import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/weight_converter.dart';
import '../../exercises/providers/exercises_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../models/workout_exercise.dart';
import '../models/workout_set.dart';
import '../providers/one_rep_max_provider.dart';
import '../providers/workout_detail_provider.dart';
import '../utils/set_resolver.dart';

class WorkoutDetailScreen extends ConsumerWidget {
  const WorkoutDetailScreen({super.key, required this.workoutId});
  final String workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(workoutDetailProvider(workoutId));
    final maxes = ref.watch(oneRepMaxProvider).asData?.value ?? const {};
    final unit = ref.watch(unitPreferenceProvider);
    // The exercises the viewer themselves can see (predefined + their own
    // custom ones) — not necessarily every exercise referenced by this
    // workout, since a workout's owner may differ from the viewer for a
    // public workout. Gates whether "set PR" is offered per set below.
    final viewerExerciseIds =
        ref.watch(exercisesProvider).asData?.value.map((e) => e.id).toSet() ?? const <String>{};
    final notifier = ref.read(workoutDetailProvider(workoutId).notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('WORKOUT'),
        actions: [
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
            for (final ex in workout.exercises)
              _ExerciseCard(
                exercise: ex,
                oneRepMaxes: maxes,
                unit: unit,
                viewerExerciseIds: viewerExerciseIds,
                onToggle: (setId, value) => notifier.setCompleted(setId, value),
              ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.oneRepMaxes,
    required this.unit,
    required this.viewerExerciseIds,
    required this.onToggle,
  });

  final WorkoutExercise exercise;
  final Map<String, double> oneRepMaxes;
  final String unit;
  final Set<String> viewerExerciseIds;
  final void Function(String setId, bool value) onToggle;

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
    return _SetTile(
      set: s,
      basisExerciseId: basisId,
      oneRepMaxKg: oneRepMaxes[basisId],
      unit: unit,
      canAddPr: viewerExerciseIds.contains(basisId),
      onToggle: onToggle,
    );
  }
}

class _SetTile extends StatelessWidget {
  const _SetTile({
    required this.set,
    required this.basisExerciseId,
    required this.oneRepMaxKg,
    required this.unit,
    required this.canAddPr,
    required this.onToggle,
  });

  final WorkoutSet set;
  final String basisExerciseId;
  final double? oneRepMaxKg;
  final String unit;
  final bool canAddPr;
  final void Function(String setId, bool value) onToggle;

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
    if (set.weightMode == 'percentage' && resolvedKg == null && canAddPr) {
      subtitle = Text.rich(
        TextSpan(
          style: baseStyle,
          children: [
            TextSpan(text: '${set.percentage?.toStringAsFixed(0)}%$basisSuffix — '),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: InkWell(
                onTap: () => context.push(AppConstants.routeAddPrForExercise(basisExerciseId)),
                child: Text(
                  'set PR',
                  style: baseStyle?.copyWith(
                    color: colorScheme.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: colorScheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else if (set.weightMode == 'percentage' && resolvedKg == null) {
      // The viewer isn't the workout's owner and can't see this exercise
      // (e.g. a custom exercise on someone else's public workout) — no
      // point offering a link that can't actually be completed.
      subtitle = Text('${set.percentage?.toStringAsFixed(0)}%$basisSuffix — no PR recorded');
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
      onChanged: (v) => onToggle(set.id, v ?? false),
      title: Text('${set.targetReps ?? '-'} reps'),
      subtitle: subtitle,
    );
  }
}
