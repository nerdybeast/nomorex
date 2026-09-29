import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/dashboard_empty_state_card.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../shared/widgets/summary_card.dart';
import '../models/program.dart';
import '../models/program_instance.dart';
import '../providers/program_instances_list_provider.dart';
import '../providers/programs_provider.dart';
import '../utils/program_progress.dart';

class ProgramsScreen extends ConsumerStatefulWidget {
  const ProgramsScreen({super.key});

  @override
  ConsumerState<ProgramsScreen> createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends ConsumerState<ProgramsScreen> {
  bool _showArchived = false;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final programsAsync =
        ref.watch(_showArchived ? archivedProgramsProvider : programsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_showArchived ? 'ARCHIVED PROGRAMS' : 'PROGRAMS'),
        actions: [
          IconButton(
            icon: programsAsync.isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: programsAsync.isRefreshing
                ? null
                : () => _showArchived
                    ? ref.read(archivedProgramsProvider.notifier).refresh()
                    : ref.read(programsProvider.notifier).refresh(),
          ),
          IconButton(
            icon: Icon(_showArchived ? Icons.archive : Icons.archive_outlined),
            tooltip: _showArchived ? 'Show active programs' : 'Show archived programs',
            onPressed: () => setState(() => _showArchived = !_showArchived),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () => context.push(AppConstants.routeProfile),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search programs...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Expanded(
            child: programsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Error: $e', style: TextStyle(color: colorScheme.error))),
              data: (programs) {
                if (programs.isEmpty) {
                  return ListView(
                    padding: shellListPadding(context),
                    children: [
                      DashboardEmptyStateCard(
                        icon: Icons.checklist_outlined,
                        title: _showArchived ? 'No archived programs.' : 'No programs yet.',
                        message: _showArchived
                            ? 'Programs you archive will show up here.'
                            : 'Tap the + button to create your first program.',
                      ),
                    ],
                  );
                }
                final query = _searchQuery.toLowerCase();
                final filtered = query.isEmpty
                    ? programs
                    : programs.where((p) {
                        final name = p.name.toLowerCase();
                        final description = (p.description ?? '').toLowerCase();
                        return name.contains(query) || description.contains(query);
                      }).toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('No programs match your search.'));
                }
                return ListView.builder(
                  padding: shellListPadding(context),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final p = filtered[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ProgramTile(program: p, showArchived: _showArchived),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgramTile extends ConsumerWidget {
  const _ProgramTile({required this.program, required this.showArchived});

  final Program program;
  final bool showArchived;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekCount = program.weeks.length;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final description = program.description?.trim();

    ProgramInstance? activeInstance;
    if (!showArchived) {
      final instances = ref.watch(currentProgramInstancesProvider).asData?.value ?? const [];
      for (final instance in instances) {
        if (instance.programId == program.id) {
          activeInstance = instance;
          break;
        }
      }
    }

    final trainingDays = countTrainingDays(
      program.weeks.map((w) => w.days.map((d) => d.isRestDay)),
    );

    return SummaryCard(
      icon: Icons.checklist_outlined,
      title: program.name,
      body: (description == null || description.isEmpty)
          ? Text(
              'No Description.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            )
          : Text(_truncatedDescription(description)),
      status: activeInstance == null
          ? null
          : Text(
              isProgramUpcoming(activeInstance.startedAt)
                  ? 'Upcoming — starts ${formatDate(activeInstance.startedAt)}'
                  : 'In progress — started ${formatDate(activeInstance.startedAt)}',
              style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600),
            ),
      chips: [
        if (!showArchived) ...[
          SummaryInfoChip(Icons.calendar_view_week_outlined, pluralize(weekCount, 'week')),
          if (trainingDays > 0)
            SummaryInfoChip(Icons.fitness_center_outlined, pluralize(trainingDays, 'training day')),
        ],
        SummaryInfoChip(
          showArchived ? Icons.archive_outlined : Icons.event_outlined,
          showArchived
              ? 'Archived ${program.archivedAt != null ? formatDate(program.archivedAt!) : ''}'.trim()
              : formatDate(program.createdAt),
        ),
      ],
      onTap: () => context.push(AppConstants.routeProgramDetail(program.id)),
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          final notifier = ref.read(programsProvider.notifier);
          if (value == 'edit') {
            if (context.mounted) context.push(AppConstants.routeProgramEdit(program.id));
          } else if (value == 'archive') {
            await notifier.archiveProgram(program.id);
          } else if (value == 'restore') {
            await notifier.restoreProgram(program.id);
          }
        },
        itemBuilder: (_) => showArchived
            ? const [PopupMenuItem(value: 'restore', child: Text('Restore'))]
            : const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'archive', child: Text('Archive')),
              ],
      ),
    );
  }

  String _truncatedDescription(String description) {
    if (description.length <= 200) return description;
    return '${description.substring(0, 200)}...';
  }
}
