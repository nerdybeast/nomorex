import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/list_group.dart';
import '../../../shared/widgets/copied_from_badge.dart';
import '../../../shared/widgets/summary_card.dart';
import '../models/program.dart';
import '../models/program_instance.dart';
import '../models/program_week.dart';
import '../providers/program_detail_provider.dart';
import '../providers/program_instances_list_provider.dart';
import '../providers/program_instances_provider.dart';
import '../utils/program_day_summary.dart';
import '../utils/program_progress.dart';
import '../widgets/program_day_card.dart';
import '../widgets/start_program_dialog.dart';

/// Read-only rollup of an authored program (mirrors WorkoutDetailScreen's
/// read affordances), plus the "Start Program" call to action that
/// materializes it into logged workouts via the start_program RPC.
class ProgramDetailScreen extends ConsumerWidget {
  const ProgramDetailScreen({super.key, required this.programId});
  final String programId;

  Future<void> _startProgram(BuildContext context, WidgetRef ref, int dayCount) async {
    final startDate = await showStartProgramDialog(context, dayCount: dayCount);
    if (startDate == null || !context.mounted) return;

    try {
      final instanceId =
          await ref.read(programInstancesProvider.notifier).startProgram(programId, startDate);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Program started.')),
      );
      context.pushReplacement(AppConstants.routeProgramInstanceDetail(instanceId));
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

    final activeInstances = ref.watch(currentProgramInstancesProvider).asData?.value ?? const [];
    ProgramInstance? activeInstance;
    for (final instance in activeInstances) {
      if (instance.programId == programId) {
        activeInstance = instance;
        break;
      }
    }

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
        error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: colorScheme.error))),
        data: (program) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(program.name, style: Theme.of(context).textTheme.headlineMedium),
            if (program.isCopy) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: CopiedFromBadge(
              isCopy: true,
              copiedFromUserId: program.copiedFromUserId,
              copiedFromDisplayName: program.copiedFromDisplayName,
              copiedFromSourceId: program.copiedFromProgramId,
            ),
              ),
            ],
            if (program.description != null && program.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(program.description!),
            ],
            const SizedBox(height: 8),
            _ProgramFacts(program: program),
            const SizedBox(height: 24),
            if (program.weeks.isEmpty)
              const Center(child: Text('This program has no weeks yet.'))
            else ...[
              if (activeInstance != null) ...[
                Text(
                  isProgramUpcoming(activeInstance.startedAt)
                      ? 'Upcoming — starts ${formatDate(activeInstance.startedAt)}'
                      : 'In progress — started ${formatDate(activeInstance.startedAt)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => context
                      .push(AppConstants.routeProgramInstanceDetail(activeInstance!.id)),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('View progress'),
                ),
              ] else
                FilledButton.icon(
                  onPressed: () => _startProgram(
                    context,
                    ref,
                    program.weeks.fold<int>(0, (sum, w) => sum + w.days.length),
                  ),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start program'),
                ),
              const SizedBox(height: 16),
              for (final week in program.weeks) _WeekSection(week: week, programId: programId),
            ],
          ],
        ),
      ),
    );
  }
}

/// Weeks, training days and created date with their icons — the same facts
/// the Programs list shows under each program.
class _ProgramFacts extends StatelessWidget {
  const _ProgramFacts({required this.program});

  final Program program;

  @override
  Widget build(BuildContext context) {
    final trainingDays = countTrainingDays(
      program.weeks.map((w) => w.days.map((d) => d.isRestDay)),
    );
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        SummaryInfoChip(Icons.calendar_view_week_outlined, pluralize(program.weeks.length, 'week')),
        if (trainingDays > 0)
          SummaryInfoChip(Icons.fitness_center_outlined, pluralize(trainingDays, 'training day')),
        SummaryInfoChip(Icons.event_outlined, formatDate(program.createdAt)),
      ],
    );
  }
}

class _WeekSection extends StatelessWidget {
  const _WeekSection({required this.week, required this.programId});

  final ProgramWeek week;
  final String programId;

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
          ListGroup(
            children: [
              for (final day in week.days)
                ProgramDayCard(
                  title: day.title,
                  subtitle: programDaySubtitle(day),
                  showChevron: programDayHasContent(day),
                  onTap: programDayHasContent(day)
                      ? () => context.push(AppConstants.routeProgramDayDetail(programId, day.id))
                      : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
