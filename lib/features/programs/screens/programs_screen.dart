import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_formatter.dart';
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
            icon: Icon(_showArchived ? Icons.archive : Icons.archive_outlined),
            tooltip: _showArchived ? 'Show active programs' : 'Show archived programs',
            onPressed: () => setState(() => _showArchived = !_showArchived),
          ),
        ],
      ),
      floatingActionButton: _showArchived
          ? null
          : FloatingActionButton.extended(
              heroTag: 'programsNewFab',
              onPressed: () => context.push(AppConstants.routeProgramNew),
              icon: const Icon(Icons.add),
              label: const Text('New program'),
            ),
      body: programsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: colorScheme.error))),
        data: (programs) {
          if (programs.isEmpty) {
            return Center(
              child: Text(_showArchived
                  ? 'No archived programs.'
                  : 'No programs yet. Tap "New program" to start.'),
            );
          }
          return ListView.builder(
            itemCount: programs.length,
            itemBuilder: (context, i) {
              final p = programs[i];
              return _ProgramTile(program: p, showArchived: _showArchived);
            },
          );
        },
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
    final colorScheme = Theme.of(context).colorScheme;

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

    return ListTile(
      title: Text(program.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            showArchived
                ? 'Archived ${program.archivedAt != null ? formatDate(program.archivedAt!) : ''}'
                : '${formatDate(program.createdAt)} · $weekCount ${weekCount == 1 ? 'week' : 'weeks'}',
          ),
          if (activeInstance != null)
            Text(
              isProgramUpcoming(activeInstance.startedAt)
                  ? 'Upcoming — starts ${formatDate(activeInstance.startedAt)}'
                  : 'In progress — started ${formatDate(activeInstance.startedAt)}',
              style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600),
            ),
        ],
      ),
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
            ? const [
                PopupMenuItem(value: 'restore', child: Text('Restore')),
              ]
            : const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'archive', child: Text('Archive')),
              ],
      ),
    );
  }
}
