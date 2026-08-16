import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/weight_converter.dart';
import '../../profile/providers/profile_provider.dart';
import '../../workouts/providers/one_rep_max_provider.dart';
import '../../workouts/utils/set_resolver.dart';
import '../models/program_exercise.dart';
import '../models/program_set.dart';
import '../providers/program_detail_provider.dart';

/// Read-only preview of a single program day's programmed exercises/sets,
/// reached by tapping a day card while browsing a program template (before
/// it's started — once running, the same tap opens the real logged workout
/// instead). Reuses the already-cached [programDetailProvider] rather than
/// issuing a new query.
class ProgramDayDetailScreen extends ConsumerWidget {
  const ProgramDayDetailScreen({super.key, required this.programId, required this.dayId});

  final String programId;
  final String dayId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(programDetailProvider(programId));
    final maxes = ref.watch(oneRepMaxProvider).asData?.value ?? const {};
    final maxesByName = ref.watch(oneRepMaxByNameProvider).asData?.value ?? const {};
    final unit = ref.watch(unitPreferenceProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: colorScheme.error))),
        data: (program) {
          final week = program.weeks.firstWhere((w) => w.days.any((d) => d.id == dayId));
          final day = week.days.firstWhere((d) => d.id == dayId);

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                title: Text(day.title.toUpperCase()),
                pinned: true,
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(
                      'WEEK ${week.weekNumber}${week.label != null ? ' — ${week.label}' : ''}',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: colorScheme.onSurfaceVariant, letterSpacing: 1),
                    ),
                    const SizedBox(height: 12),
                    if (day.isRestDay)
                      const Text('Rest day')
                    else if (day.exercises.isEmpty)
                      const Text('No workout scheduled')
                    else
                      for (final ex in day.exercises)
                        _ExerciseCard(
                          exercise: ex,
                          oneRepMaxes: maxes,
                          oneRepMaxesByName: maxesByName,
                          unit: unit,
                        ),
                  ]),
                ),
              ),
            ],
          );
        },
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

  final ProgramExercise exercise;
  final Map<String, double> oneRepMaxes;
  final Map<String, double> oneRepMaxesByName;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exercise.exerciseName, style: theme.textTheme.titleMedium),
            if (exercise.notes != null && exercise.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  exercise.notes!,
                  style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            const Divider(height: 16),
            for (final s in exercise.sets)
              _SetLines(
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

class _SetLines extends StatelessWidget {
  const _SetLines({
    required this.set,
    required this.exercise,
    required this.oneRepMaxes,
    required this.oneRepMaxesByName,
    required this.unit,
  });

  final ProgramSet set;
  final ProgramExercise exercise;
  final Map<String, double> oneRepMaxes;
  final Map<String, double> oneRepMaxesByName;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final basisExerciseId = set.basisExerciseId ?? exercise.exerciseId;
    // Name fallback matters here because this screen also renders another
    // user's public program, whose exercise ids belong to *their* catalog —
    // an id-only lookup would silently never resolve. See lookupOneRepMaxKg.
    final oneRepMaxKg = lookupOneRepMaxKg(
      basisExerciseId: basisExerciseId,
      basisExerciseName: set.basisExerciseId != null
          ? (set.basisExerciseName ?? exercise.exerciseName)
          : exercise.exerciseName,
      byExerciseId: oneRepMaxes,
      byExerciseName: oneRepMaxesByName,
    );
    final resolvedKg = resolveSetWeightKg(
      weightMode: set.weightMode,
      percentage: set.percentage,
      absoluteWeightKg: set.absoluteWeightKg,
      oneRepMaxKg: oneRepMaxKg,
    );

    final repsLabel = '${set.targetReps ?? '-'} ${set.targetReps == 1 ? 'rep' : 'reps'}';

    String firstLine;
    String? secondLine;
    if (set.weightMode == 'percentage') {
      final basisLabel = set.basisExerciseId != null ? (set.basisExerciseName ?? '1RM') : '1RM';
      firstLine = '$repsLabel · ${set.percentage?.toStringAsFixed(0) ?? '?'}% of $basisLabel';
      if (oneRepMaxKg != null && resolvedKg != null) {
        secondLine =
            '${formatWeightForPreference(oneRepMaxKg, unit)} PR ≈ ${formatWeightForPreference(resolvedKg, unit)}';
      }
    } else {
      firstLine = '$repsLabel · ${formatWeightForPreference(set.absoluteWeightKg ?? 0, unit)}';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(firstLine, style: theme.textTheme.bodyMedium),
          if (secondLine != null)
            Text(secondLine, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
