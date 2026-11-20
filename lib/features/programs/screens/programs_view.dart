import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/archived_toggle.dart';
import '../../../shared/widgets/archived_row_actions.dart';
import '../../../shared/widgets/list_group.dart';
import '../../../shared/widgets/copied_from_badge.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/dashboard_empty_state_card.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../shared/widgets/summary_card.dart';
import '../utils/program_stats.dart';
import '../widgets/program_run_status.dart';
import '../widgets/program_stats_chips.dart';
import '../models/program.dart';
import '../models/program_instance.dart';
import '../providers/program_instances_list_provider.dart';
import '../providers/programs_provider.dart';
import '../utils/program_progress.dart';

/// Training's Programs view: search, the Archived toggle and the list. It has
/// no app bar of its own; `TrainingScreen` supplies one, calling [refresh] and
/// [isRefreshing] for its Refresh action.
class ProgramsView extends ConsumerStatefulWidget {
  const ProgramsView({super.key});

  static bool isRefreshing(WidgetRef ref) =>
      ref.watch(programsProvider).isRefreshing || ref.watch(archivedProgramsProvider).isRefreshing;

  static void refresh(WidgetRef ref) {
    ref.read(programsProvider.notifier).refresh();
    ref.read(archivedProgramsProvider.notifier).refresh();
  }

  @override
  ConsumerState<ProgramsView> createState() => _ProgramsViewState();
}

class _ProgramsViewState extends ConsumerState<ProgramsView> {
  String _searchQuery = '';
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final activeAsync = ref.watch(programsProvider);
    final archivedAsync = ref.watch(archivedProgramsProvider);

    return Column(
      children: [
        Padding(
          padding: contentPadding(context, top: 12, bottom: 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('programs_search'),
                  decoration: InputDecoration(
                    hintText: _showArchived ? 'Search archived programs...' : 'Search programs...',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              const SizedBox(width: 8),
              ArchivedToggle(
                key: const Key('archived_toggle'),
                selected: _showArchived,
                count: archivedAsync.asData?.value.length,
                onChanged: (v) => setState(() => _showArchived = v),
              ),
            ],
          ),
        ),
        Expanded(
          child: _showArchived
              ? _ProgramList(key: const ValueKey('archived'), programsAsync: archivedAsync, archived: true, query: _searchQuery)
              : _ProgramList(key: const ValueKey('active'), programsAsync: activeAsync, archived: false, query: _searchQuery),
        ),
      ],
    );
  }
}

class _ProgramList extends StatelessWidget {
  const _ProgramList({super.key, required this.programsAsync, required this.archived, required this.query});

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

    // A running program reads "2 of 8 weeks"; otherwise plain totals from the
    // template. The run's own structure wins so "of Y" matches what it started
    // with even if the template was edited since.
    final stats = activeInstance?.stats ??
        templateStats([
          for (final w in program.weeks)
            StatsWeek([
              for (final d in w.days)
                StatsDay.fromDay(d),
            ]),
        ]);

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
              isImported: program.isImported,
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
          : Text(description),
      status: activeInstance == null
          ? null
          : ProgramRunStatus(
              upcoming: isProgramUpcoming(activeInstance.startedAt),
              date: formatDate(activeInstance.startedAt),
            ),
      // The created date lives on the program screen; here it wrapped onto a
      // line of its own and repeated the days chip's calendar icon. The list
      // is already sorted by it.
      chips: programStatsChips(stats),
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
}
