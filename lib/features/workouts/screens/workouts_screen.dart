import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/active_archived_tabs.dart';
import '../../../shared/widgets/archived_row_actions.dart';
import '../../../shared/widgets/list_group.dart';
import '../../../shared/widgets/dashboard_empty_state_card.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../shared/widgets/copied_from_badge.dart';
import '../../../shared/widgets/summary_card.dart';
import '../models/workout.dart';
import '../providers/workouts_provider.dart';
import '../utils/can_archive_workout.dart';
import '../utils/confirm_delete_workout_permanently.dart';

class WorkoutsScreen extends ConsumerStatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  ConsumerState<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends ConsumerState<WorkoutsScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final activeAsync = ref.watch(workoutsProvider);
    final archivedAsync = ref.watch(archivedWorkoutsProvider);
    final isRefreshing = activeAsync.isRefreshing || archivedAsync.isRefreshing;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Workouts'),
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
                      ref.read(workoutsProvider.notifier).refresh();
                      ref.read(archivedWorkoutsProvider.notifier).refresh();
                    },
            ),
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'Workout history',
              onPressed: () => context.push(AppConstants.routeWorkoutHistory),
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
                  hintText: 'Search workouts...',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _WorkoutList(workoutsAsync: activeAsync, archived: false, query: _searchQuery),
                  _WorkoutList(workoutsAsync: archivedAsync, archived: true, query: _searchQuery),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutList extends StatelessWidget {
  const _WorkoutList({required this.workoutsAsync, required this.archived, required this.query});

  final AsyncValue<List<Workout>> workoutsAsync;
  final bool archived;
  final String query;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return workoutsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: colorScheme.error))),
      data: (workouts) {
        if (workouts.isEmpty) {
          return ListView(
            padding: shellListPadding(context),
            children: [
              DashboardEmptyStateCard(
                ctaStyle: EmptyStateCtaStyle.link,
                icon: archived ? Icons.archive_outlined : Icons.fitness_center_outlined,
                title: archived ? 'No archived workouts' : 'No workouts yet.',
                message: archived
                    ? 'Workouts you archive show up here.'
                    : 'Create a workout to start logging your training.',
                ctaLabel: archived ? null : 'Create your first workout',
                onCta: archived ? null : () => context.push(AppConstants.routeWorkoutNew),
              ),
            ],
          );
        }
        final filtered = query.isEmpty
            ? workouts
            : workouts.where((w) => w.title.toLowerCase().contains(query.toLowerCase())).toList();
        if (filtered.isEmpty) {
          return const Center(child: Text('No workouts match your search.'));
        }
        // Rows in one bordered container rather than a card each.
        return ListView(
          padding: shellListPadding(context),
          children: [
            ListGroup(
              children: [
                for (final w in filtered)
                  archived ? _ArchivedWorkoutTile(workout: w) : _WorkoutTile(workout: w),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _WorkoutTile extends ConsumerWidget {
  const _WorkoutTile({required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = workout;
    final names = w.exercises.map((e) => e.exerciseName).where((n) => n.isNotEmpty).toList();
    final text = names.isEmpty ? w.notes?.trim() : exercisePreview(names);
    final statusLabel = switch (w.status) {
      'in_progress' => 'In progress',
      'paused' => 'Paused',
      'finished' => 'Finished',
      _ => null,
    };
    return SummaryCard(
      icon: Icons.fitness_center_outlined,
      title: w.title,
      badge: w.isCopy
          ? CopiedFromBadge(
              isCopy: true,
              copiedFromUserId: w.copiedFromUserId,
              copiedFromDisplayName: w.copiedFromDisplayName,
              copiedFromSourceId: w.copiedFromSourceId,
            )
          : null,
      body: text == null || text.isEmpty
          ? null
          : Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
      status: statusLabel == null
          ? null
          : Text(
              statusLabel,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
      chips: [
        SummaryInfoChip(Icons.event_outlined, formatDate(w.date)),
        SummaryInfoChip(Icons.list_alt_outlined, pluralize(w.exercises.length, 'exercise')),
      ],
      onTap: () => context.push(AppConstants.routeWorkoutDetail(w.id)),
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          final notifier = ref.read(workoutsProvider.notifier);
          if (value == 'duplicate') {
            await notifier.duplicateWorkout(w.id);
          } else if (value == 'edit') {
            if (context.mounted) context.push(AppConstants.routeWorkoutEdit(w.id));
          } else if (value == 'archive') {
            await notifier.archiveWorkout(w);
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
          // A live session has to be finished or discarded first.
          if (canArchiveWorkout(w)) const PopupMenuItem(value: 'archive', child: Text('Archive')),
        ],
      ),
    );
  }
}

class _ArchivedWorkoutTile extends ConsumerWidget {
  const _ArchivedWorkoutTile({required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = workout;
    return SummaryCard(
      archived: true,
      icon: Icons.fitness_center_outlined,
      title: w.title,
      chips: [
        SummaryInfoChip(
          Icons.archive_outlined,
          'Archived ${w.archivedAt != null ? formatDate(w.archivedAt!) : ''}'.trim(),
        ),
      ],
      onTap: () => context.push(AppConstants.routeWorkoutDetail(w.id)),
      trailing: ArchivedRowActions(
        onRestore: () => ref.read(workoutsProvider.notifier).restoreWorkout(w),
        onDelete: () => confirmAndDeleteWorkoutPermanently(context, ref, w),
      ),
    );
  }
}
