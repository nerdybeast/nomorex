import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/copied_from_badge.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_formatter.dart';
import '../models/program_instance.dart';
import '../models/program_week.dart';
import '../providers/program_instances_provider.dart';
import '../providers/program_detail_provider.dart';
import '../providers/program_instance_detail_provider.dart';
import '../providers/program_instance_workouts_provider.dart';
import '../utils/program_day_summary.dart';
import '../utils/program_progress.dart';
import '../../../shared/widgets/list_group.dart';
import '../utils/program_stats.dart';
import '../widgets/program_day_card.dart';
import '../widgets/program_stats_chips.dart';

/// A running (or upcoming) program: the same week/day layout as the
/// template browse screen, but each day is highlighted if it's today and
/// its chevron opens the real, loggable workout for that day rather than a
/// read-only preview.
class ProgramInstanceDetailScreen extends ConsumerWidget {
  const ProgramInstanceDetailScreen({super.key, required this.instanceId});

  final String instanceId;

  static String _statusLabel(ProgramInstance instance, bool upcoming) {
    if (!instance.isActive) {
      final verb = instance.status == 'abandoned' ? 'Abandoned' : 'Completed';
      final endedAt = instance.completedAt;
      return endedAt == null ? verb : '$verb ${formatDate(endedAt.toLocal())}';
    }
    return upcoming
        ? 'Upcoming — starts ${formatDate(instance.startedAt)}'
        : 'Started ${formatDate(instance.startedAt)}';
  }

  Future<void> _confirmEnd(
    BuildContext context,
    WidgetRef ref, {
    required bool complete,
  }) async {
    final noun = complete ? 'Complete' : 'Abandon';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$noun this program?'),
        content: Text(
          complete
              ? 'It will move to your program history. Your logged workouts are kept.'
              : 'It will move to your program history marked as abandoned. Your logged workouts are kept.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(noun)),
        ],
      ),
    );
    if (confirmed != true) return;
    final notifier = ref.read(programInstancesProvider.notifier);
    if (complete) {
      await notifier.completeProgramInstance(instanceId);
    } else {
      await notifier.abandonProgramInstance(instanceId);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final instanceAsync = ref.watch(programInstanceDetailProvider(instanceId));
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Program')),
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
                Text(instance.programName ?? program.name, style: Theme.of(context).textTheme.headlineMedium),
                if (program.isCopy) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: CopiedFromBadge(
              isCopy: true,
              isImported: program.isImported,
              copiedFromUserId: program.copiedFromUserId,
              copiedFromDisplayName: program.copiedFromDisplayName,
              copiedFromSourceId: program.copiedFromProgramId,
            ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  _statusLabel(instance, upcoming),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                if (instance.stats case final stats?) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 12, runSpacing: 4, children: programStatsChips(stats)),
                ],
                if (instance.isActive) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // The theme makes FilledButton full-width, so it must be
                      // Expanded inside a Row (unbounded width otherwise).
                      Expanded(
                        child: FilledButton(
                          key: const Key('program_instance_complete'),
                          onPressed: () => _confirmEnd(context, ref, complete: true),
                          child: const Text('Complete program'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        key: const Key('program_instance_abandon'),
                        onPressed: () => _confirmEnd(context, ref, complete: false),
                        child: const Text('Abandon'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                for (final week in program.weeks)
                  _InstanceWeekSection(
                    week: week,
                    instance: instance,
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
    required this.instance,
    required this.dayToWorkoutId,
  });

  final ProgramWeek week;
  final ProgramInstance instance;
  final Map<String, String> dayToWorkoutId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  'Week ${week.weekNumber}${week.label != null ? ' — ${week.label}' : ''}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (instance.isWeekCheckedFor(StatsWeek.fromWeek(week))) ...[
                const SizedBox(width: 8),
                const CompletedCheck(key: Key('program_week_completed'), size: 22),
              ],
            ],
          ),
          const SizedBox(height: 8),
          ListGroup(
            children: [
              for (final day in week.days)
                ProgramDayCard(
                  title: day.title,
                  subtitle: programDaySubtitle(day),
                  highlighted: isProgramDayToday(instance.startedAt, day.position),
                  completed: instance.isDayCheckedFor(StatsDay.fromDay(day)),
                  showChevron: programDayHasContent(day) && dayToWorkoutId.containsKey(day.id),
                  onTap: dayToWorkoutId.containsKey(day.id)
                      ? () => context.push(AppConstants.routeWorkoutDetail(dayToWorkoutId[day.id]!))
                      : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
