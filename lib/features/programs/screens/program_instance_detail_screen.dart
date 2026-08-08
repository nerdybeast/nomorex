import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_formatter.dart';
import '../models/program_week.dart';
import '../providers/program_detail_provider.dart';
import '../providers/program_instance_detail_provider.dart';
import '../providers/program_instance_workouts_provider.dart';
import '../utils/program_day_summary.dart';
import '../utils/program_progress.dart';
import '../widgets/program_day_card.dart';

/// A running (or upcoming) program: the same week/day layout as the
/// template browse screen, but each day is highlighted if it's today and
/// its chevron opens the real, loggable workout for that day rather than a
/// read-only preview.
class ProgramInstanceDetailScreen extends ConsumerWidget {
  const ProgramInstanceDetailScreen({super.key, required this.instanceId});

  final String instanceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final instanceAsync = ref.watch(programInstanceDetailProvider(instanceId));
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('PROGRAM')),
      body: instanceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: colorScheme.error))),
        data: (instance) {
          final programAsync = ref.watch(programDetailProvider(instance.programId));
          final dayToWorkoutId =
              ref.watch(programInstanceWorkoutsProvider(instanceId)).asData?.value ?? const {};
          final upcoming = isProgramUpcoming(instance.startedAt);

          return programAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: colorScheme.error))),
            data: (program) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(instance.programName ?? program.name, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  upcoming
                      ? 'Upcoming — starts ${formatDate(instance.startedAt)}'
                      : 'Started ${formatDate(instance.startedAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                for (final week in program.weeks)
                  _InstanceWeekSection(
                    week: week,
                    startedAt: instance.startedAt,
                    dayToWorkoutId: dayToWorkoutId,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InstanceWeekSection extends StatelessWidget {
  const _InstanceWeekSection({
    required this.week,
    required this.startedAt,
    required this.dayToWorkoutId,
  });

  final ProgramWeek week;
  final DateTime startedAt;
  final Map<String, String> dayToWorkoutId;

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
          const SizedBox(height: 8),
          for (final day in week.days)
            ProgramDayCard(
              title: day.title,
              subtitle: programDaySubtitle(day),
              highlighted: isProgramDayToday(startedAt, day.position),
              showChevron: programDayHasContent(day) && dayToWorkoutId.containsKey(day.id),
              onTap: dayToWorkoutId.containsKey(day.id)
                  ? () => context.push(AppConstants.routeWorkoutDetail(dayToWorkoutId[day.id]!))
                  : null,
            ),
        ],
      ),
    );
  }
}
