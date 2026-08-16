import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/dark_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/owner_name.dart';
import '../../../core/utils/weight_converter.dart';
import '../../../shared/widgets/set_pr_link.dart';
import '../../profile/providers/profile_provider.dart';
import '../../workouts/models/workout_exercise.dart';
import '../../workouts/models/workout_set.dart';
import '../../workouts/providers/one_rep_max_provider.dart';
import '../../workouts/utils/set_resolver.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('WORKOUT'),
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
            Text(workout.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'by ${ownerDisplayName(workout.ownerDisplayName)} · ${formatDate(workout.date)}',
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
            if (workout.notes != null && workout.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(workout.notes!),
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
  final Map<String, double> oneRepMaxes;
  final Map<String, double> oneRepMaxesByName;
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
  final Map<String, double> oneRepMaxes;
  final Map<String, double> oneRepMaxesByName;
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
    final resolvedKg = resolveSetWeightKg(
      weightMode: set.weightMode,
      percentage: set.percentage,
      absoluteWeightKg: set.absoluteWeightKg,
      oneRepMaxKg: lookupOneRepMaxKg(
        basisExerciseId: basisId,
        basisExerciseName: basisName,
        byExerciseId: oneRepMaxes,
        byExerciseName: oneRepMaxesByName,
      ),
    );

    // "70% 1RM" normally, but "75% of Clean & Jerk" when the set is programmed
    // against a different lift — otherwise the resolved weight beside it looks
    // wrong for the exercise it's filed under.
    final basisLabel = set.basisExerciseId != null ? 'of $basisName' : '1RM';
    final target = '$reps · ${set.percentage?.toStringAsFixed(0)}% $basisLabel · ';

    final baseStyle = DefaultTextStyle.of(context).style;
    final accent = Theme.of(context).extension<NomorexDarkTokens>()?.secondaryAccent;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text.rich(
        TextSpan(
          style: baseStyle,
          children: [
            TextSpan(text: target),
            if (resolvedKg != null)
              TextSpan(
                text: formatWeightForPreference(resolvedKg, unit),
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
