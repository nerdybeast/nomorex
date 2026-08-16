import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/owner_name.dart';
import '../../programs/models/program_week.dart';
import '../../programs/utils/program_day_summary.dart';
import '../../programs/widgets/program_day_card.dart';
import '../providers/community_program_detail_provider.dart';

/// Read-only preview of another user's public program, mirroring
/// [CommunityWorkoutDetailScreen]. Deliberately offers no "Start Program"
/// button: starting materializes the template into the viewer's own workouts,
/// which is an authoring action on someone else's template rather than a
/// preview, so it stays out of this screen's scope.
class CommunityProgramDetailScreen extends ConsumerWidget {
  const CommunityProgramDetailScreen({super.key, required this.programId});
  final String programId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(communityProgramDetailProvider(programId));
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PROGRAM'),
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
        data: (program) {
          final weeks = program.weeks.length;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(program.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'by ${ownerDisplayName(program.ownerDisplayName)} · '
                '$weeks ${weeks == 1 ? 'week' : 'weeks'}',
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
              if (program.description != null && program.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(program.description!),
              ],
              const SizedBox(height: 16),
              if (program.weeks.isEmpty)
                const Center(child: Text('This program has no weeks yet.'))
              else
                for (final week in program.weeks) _WeekSection(week: week, programId: programId),
            ],
          );
        },
      ),
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
          for (final day in week.days)
            ProgramDayCard(
              title: day.title,
              subtitle: programDaySubtitle(day),
              showChevron: programDayHasContent(day),
              // ProgramDayDetailScreen has no edit affordances of its own, so
              // it doubles as the read-only day view for a foreign program.
              onTap: programDayHasContent(day)
                  ? () => context.push(AppConstants.routeProgramDayDetail(programId, day.id))
                  : null,
            ),
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
