import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_formatter.dart';
import '../models/program_instance.dart';
import '../providers/finished_program_instances_provider.dart';
import '../widgets/program_stats_chips.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../shell/widgets/breadcrumb_title.dart';

/// Program runs the user has completed or abandoned, most recent first —
/// the Programs-page counterpart of the Workout history screen.
class ProgramHistoryScreen extends ConsumerWidget {
  const ProgramHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(finishedProgramInstancesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const BreadcrumbTitle(title: 'Program history')),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: colorScheme.error))),
        data: (instances) {
          if (instances.isEmpty) {
            return const Center(child: Text("You haven't completed any programs yet."));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final instance in instances)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _HistoryEntryCard(
                    instance: instance,
                    onTap: () => context.push(AppConstants.routeProgramInstanceDetail(instance.id)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HistoryEntryCard extends StatelessWidget {
  const _HistoryEntryCard({required this.instance, this.onTap});

  final ProgramInstance instance;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleStyle =
        theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final endedAt = instance.completedAt;
    final verb = instance.status == 'abandoned' ? 'Abandoned' : 'Completed';

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: contentPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                instance.programName ?? 'Program',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                endedAt == null ? verb : '$verb ${formatDate(endedAt.toLocal())}',
                style: subtitleStyle,
              ),
              Text('Started ${formatDate(instance.startedAt)}', style: subtitleStyle),
              if (instance.stats case final stats?) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 12, runSpacing: 4, children: programStatsChips(stats)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
