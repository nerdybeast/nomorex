import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/weight_converter.dart';
import '../../profile/providers/profile_provider.dart';
import '../models/program_day.dart';
import '../models/program_week.dart';
import '../providers/program_detail_provider.dart';

/// Read-only rollup of an authored program (mirrors WorkoutDetailScreen's
/// read affordances). Starting the program is wired in separately once the
/// materialization RPC exists.
class ProgramDetailScreen extends ConsumerWidget {
  const ProgramDetailScreen({super.key, required this.programId});
  final String programId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(programDetailProvider(programId));
    final unit = ref.watch(unitPreferenceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Program'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(AppConstants.routeProgramEdit(programId)),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (program) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(program.name, style: Theme.of(context).textTheme.headlineSmall),
            if (program.description != null && program.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(program.description!),
            ],
            const SizedBox(height: 4),
            Text(
              '${program.weeks.length} ${program.weeks.length == 1 ? 'week' : 'weeks'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (program.weeks.isEmpty)
              const Center(child: Text('This program has no weeks yet.'))
            else
              for (final week in program.weeks) _WeekSection(week: week, unit: unit),
          ],
        ),
      ),
    );
  }
}

class _WeekSection extends StatelessWidget {
  const _WeekSection({required this.week, required this.unit});

  final ProgramWeek week;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Week ${week.weekNumber}${week.label != null ? ' — ${week.label}' : ''}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (week.notes != null && week.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(week.notes!, style: Theme.of(context).textTheme.bodySmall),
            ),
          const SizedBox(height: 8),
          for (final day in week.days) _DaySection(day: day, unit: unit),
        ],
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({required this.day, required this.unit});

  final ProgramDay day;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(day.title, style: Theme.of(context).textTheme.titleMedium),
            if (day.isRestDay)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('Rest day', style: Theme.of(context).textTheme.bodySmall),
              )
            else ...[
              if (day.notes != null && day.notes!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(day.notes!, style: Theme.of(context).textTheme.bodySmall),
                ),
              for (final ex in day.exercises)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ex.exerciseName, style: Theme.of(context).textTheme.bodyLarge),
                      if (ex.notes != null && ex.notes!.isNotEmpty)
                        Text(ex.notes!, style: Theme.of(context).textTheme.bodySmall),
                      for (final s in ex.sets)
                        Padding(
                          padding: const EdgeInsets.only(left: 8, top: 2),
                          child: Text(
                            '${s.targetReps ?? '-'} reps · ${_valueLabel(s.weightMode, s.percentage, s.absoluteWeightKg, s.basisExerciseId, s.basisExerciseName, unit)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _valueLabel(
    String weightMode,
    double? percentage,
    double? absoluteWeightKg,
    String? basisExerciseId,
    String? basisExerciseName,
    String unit,
  ) {
    if (weightMode == 'percentage') {
      final basisLabel = basisExerciseId != null ? (basisExerciseName ?? '1RM') : '1RM';
      return '${percentage?.toStringAsFixed(0) ?? '?'}% of $basisLabel';
    }
    return absoluteWeightKg != null ? formatWeight(absoluteWeightKg, unit) : '? $unit';
  }
}
