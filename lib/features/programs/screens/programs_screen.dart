import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/active_archived_tabs.dart';
import '../../../shared/widgets/archived_row_actions.dart';
import '../../../shared/widgets/list_group.dart';
import '../../../shared/widgets/copied_from_badge.dart';
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
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final activeAsync = ref.watch(programsProvider);
    final archivedAsync = ref.watch(archivedProgramsProvider);
    final isRefreshing = activeAsync.isRefreshing || archivedAsync.isRefreshing;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Programs'),
          actions: [
            IconButton(
              icon: isRefreshing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: isRefreshing
                  ? null
                  : () {
                      ref.read(programsProvider.notifier).refresh();
                      ref.read(archivedProgramsProvider.notifier).refresh();
                    },
            ),
            IconButton(
              icon: const Icon(Icons.person_outline),
              tooltip: 'Profile',
              onPressed: () => context.push(AppConstants.routeProfile),
            ),
          ],
          bottom: ActiveArchivedTabs(
            activeCount: activeAsync.asData?.value.length,
            archivedCount: archivedAsync.asData?.value.length,
          ),
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
              child: TabBarView(
                children: [
                  _ProgramList(programsAsync: activeAsync, archived: false, query: _searchQuery),
                  _ProgramList(programsAsync: archivedAsync, archived: true, query: _searchQuery),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgramList extends StatelessWidget {
  const _ProgramList({required this.programsAsync, required this.archived, required this.query});

  final AsyncValue<List<Program>> programsAsync;
  final bool archived;
  final String query;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return programsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          Center(child: Text('Error: $e', style: TextStyle(color: colorScheme.error))),
      data: (programs) {
        if (programs.isEmpty) {
          return ListView(
            padding: shellListPadding(context),
            children: [
              DashboardEmptyStateCard(
                ctaStyle: EmptyStateCtaStyle.link,
                icon: archived ? Icons.archive_outlined : Icons.checklist_outlined,
                title: archived ? 'No archived programs' : 'No programs yet.',
                message: archived
                    ? 'Programs you archive show up here.'
                    : 'Build a reusable template to plan your training.',
                ctaLabel: archived ? null : 'Create your first program',
                onCta: archived ? null : () => context.push(AppConstants.routeProgramNew),
              ),
            ],
          );
        }
        final q = query.toLowerCase();
        final filtered = q.isEmpty
            ? programs
            : programs.where((p) {
                final name = p.name.toLowerCase();
                final description = (p.description ?? '').toLowerCase();
                return name.contains(q) || description.contains(q);
              }).toList();
        if (filtered.isEmpty) {
          return const Center(child: Text('No programs match your search.'));
        }
        // Rows in one bordered container rather than a card each.
        return ListView(
          padding: shellListPadding(context),
          children: [
            ListGroup(
              children: [
                for (final p in filtered) _ProgramTile(program: p, showArchived: archived),
              ],
            ),
          ],
        );
      },
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

    if (showArchived) {
      return SummaryCard(
        archived: true,
        icon: Icons.checklist_outlined,
        title: program.name,
        chips: [
          SummaryInfoChip(
            Icons.archive_outlined,
            'Archived ${program.archivedAt != null ? formatDate(program.archivedAt!) : ''}'.trim(),
          ),
        ],
        onTap: () => context.push(AppConstants.routeProgramDetail(program.id)),
        trailing: ArchivedRowActions(
          onRestore: () => ref.read(programsProvider.notifier).restoreProgram(program.id),
        ),
      );
    }

    return SummaryCard(
      icon: Icons.checklist_outlined,
      title: program.name,
      badge: program.isCopy
          ? CopiedFromBadge(
              isCopy: true,
              copiedFromUserId: program.copiedFromUserId,
              copiedFromDisplayName: program.copiedFromDisplayName,
              copiedFromSourceId: program.copiedFromProgramId,
            )
          : null,
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
        SummaryInfoChip(Icons.calendar_view_week_outlined, pluralize(weekCount, 'week')),
        if (trainingDays > 0)
          SummaryInfoChip(Icons.fitness_center_outlined, pluralize(trainingDays, 'training day')),
        SummaryInfoChip(Icons.event_outlined, formatDate(program.createdAt)),
      ],
      onTap: () => context.push(AppConstants.routeProgramDetail(program.id)),
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          final notifier = ref.read(programsProvider.notifier);
          if (value == 'edit') {
            if (context.mounted) context.push(AppConstants.routeProgramEdit(program.id));
          } else if (value == 'archive') {
            await notifier.archiveProgram(program.id);
          }
        },
        itemBuilder: (_) => const [
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
