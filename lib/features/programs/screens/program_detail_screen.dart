import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/weight_converter.dart';
import '../models/program_day.dart';
import '../models/program_week.dart';
import '../providers/program_detail_provider.dart';
import '../providers/program_instances_provider.dart';
import '../utils/program_day_date.dart';

/// Read-only rollup of an authored program (mirrors WorkoutDetailScreen's
/// read affordances), plus the "Start Program" call to action that
/// materializes it into logged workouts via the start_program RPC.
class ProgramDetailScreen extends ConsumerWidget {
  const ProgramDetailScreen({super.key, required this.programId});
  final String programId;

  Future<void> _startProgram(BuildContext context, WidgetRef ref, int dayCount) async {
    var startDate = DateTime.now();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Start Program'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Start date'),
                subtitle: Text(formatDate(startDate)),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: startDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                  );
                  if (picked != null) setState(() => startDate = picked);
                },
              ),
              if (dayCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Ends around ${formatDate(programDayDate(startDate, dayCount - 1))}.',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Start')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(programInstancesProvider.notifier).startProgram(programId, startDate);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Program started — check your workouts.')),
      );
      context.go(AppConstants.routeWorkouts);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not start program: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(programDetailProvider(programId));
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PROGRAM'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(AppConstants.routeProgramEdit(programId)),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: colorScheme.error))),
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
            else ...[
              FilledButton.icon(
                onPressed: () => _startProgram(
                  context,
                  ref,
                  program.weeks.fold<int>(0, (sum, w) => sum + w.days.length),
                ),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Program'),
              ),
              const SizedBox(height: 16),
              for (final week in program.weeks) _WeekSection(week: week),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeekSection extends StatelessWidget {
  const _WeekSection({required this.week});

  final ProgramWeek week;

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
          for (final day in week.days) _DaySection(day: day),
        ],
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({required this.day});

  final ProgramDay day;

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
                            '${s.targetReps ?? '-'} reps · ${_valueLabel(s.weightMode, s.percentage, s.absoluteWeightKg, s.basisExerciseId, s.basisExerciseName)}',
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
  ) {
    if (weightMode == 'percentage') {
      final basisLabel = basisExerciseId != null ? (basisExerciseName ?? '1RM') : '1RM';
      return '${percentage?.toStringAsFixed(0) ?? '?'}% of $basisLabel';
    }
    return absoluteWeightKg != null ? formatWeightBoth(absoluteWeightKg) : '? lbs / ? kg';
  }
}
