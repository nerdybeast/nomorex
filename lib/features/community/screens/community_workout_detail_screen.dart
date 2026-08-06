import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/weight_converter.dart';
import '../../workouts/models/workout_exercise.dart';
import '../../workouts/models/workout_set.dart';
import '../providers/community_workout_detail_provider.dart';

class CommunityWorkoutDetailScreen extends ConsumerWidget {
  const CommunityWorkoutDetailScreen({super.key, required this.workoutId});
  final String workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(communityWorkoutDetailProvider(workoutId));

    return Scaffold(
      appBar: AppBar(title: const Text('Workout')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (workout) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(workout.title, style: Theme.of(context).textTheme.headlineSmall),
            Text(formatDate(workout.date)),
            if (workout.notes != null && workout.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(workout.notes!),
            ],
            const SizedBox(height: 16),
            for (final ex in workout.exercises) _ExerciseCard(exercise: ex),
          ],
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.exercise});

  final WorkoutExercise exercise;

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
            for (final s in exercise.sets) _SetRow(set: s),
          ],
        ),
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({required this.set});

  final WorkoutSet set;

  @override
  Widget build(BuildContext context) {
    // Read-only preview of the workout's targets — deliberately not resolved
    // against the viewer's own 1RM, since a percentage set here belongs to
    // the workout's owner, not the current user.
    final String text;
    if (set.weightMode == 'percentage') {
      text = '${set.targetReps ?? '-'} reps · ${set.percentage?.toStringAsFixed(0)}% 1RM';
    } else {
      text = '${set.targetReps ?? '-'} reps · ${formatWeightBoth(set.absoluteWeightKg ?? 0)}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(text),
    );
  }
}
