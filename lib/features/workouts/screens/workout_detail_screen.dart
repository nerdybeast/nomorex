import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/weight_converter.dart';
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
    required this.onToggle,
  });

  final WorkoutExercise exercise;
  final Map<String, double> oneRepMaxes;
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
            for (final s in exercise.sets)
              _SetTile(
                set: s,
                oneRepMaxKg: oneRepMaxes[resolveBasisExerciseId(s, exercise)],
                onToggle: onToggle,
              ),
          ],
        ),
      ),
    );
  }
}

class _SetTile extends StatelessWidget {
  const _SetTile({
    required this.set,
    required this.oneRepMaxKg,
    required this.onToggle,
  });

  final WorkoutSet set;
  final double? oneRepMaxKg;
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
    final String trailingText;
    if (set.weightMode == 'percentage') {
      trailingText = resolvedKg == null
          ? '${set.percentage?.toStringAsFixed(0)}%$basisSuffix — set a 1RM'
          : '${set.percentage?.toStringAsFixed(0)}%$basisSuffix · ${formatWeightBoth(resolvedKg)}';
    } else {
      trailingText = formatWeightBoth(resolvedKg ?? 0);
    }

    return CheckboxListTile(
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      value: set.completed,
      onChanged: (v) => onToggle(set.id, v ?? false),
      title: Text('${set.targetReps ?? '-'} reps'),
      subtitle: Text(trailingText),
    );
  }
}
