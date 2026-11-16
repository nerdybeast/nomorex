import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/archived_toggle.dart';
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

/// Training's Workouts view: search, the Archived toggle and the list. It has
/// no app bar of its own; `TrainingScreen` supplies one, calling [refresh] and
/// [isRefreshing] for its Refresh action.
class WorkoutsView extends ConsumerStatefulWidget {
  const WorkoutsView({super.key});

  static bool isRefreshing(WidgetRef ref) =>
      ref.watch(workoutsProvider).isRefreshing || ref.watch(archivedWorkoutsProvider).isRefreshing;

  static void refresh(WidgetRef ref) {
    ref.read(workoutsProvider.notifier).refresh();
    ref.read(archivedWorkoutsProvider.notifier).refresh();
  }

  @override
  ConsumerState<WorkoutsView> createState() => _WorkoutsViewState();
}

class _WorkoutsViewState extends ConsumerState<WorkoutsView> {
  String _searchQuery = '';
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final activeAsync = ref.watch(workoutsProvider);
    final archivedAsync = ref.watch(archivedWorkoutsProvider);

    return Column(
      children: [
        Padding(
          padding: contentPadding(context, top: 12, bottom: 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('workouts_search'),
                  decoration: InputDecoration(
                    hintText: _showArchived ? 'Search archived workouts...' : 'Search workouts...',
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
              ? _WorkoutList(key: const ValueKey('archived'), workoutsAsync: archivedAsync, archived: true, query: _searchQuery)
              : _WorkoutList(key: const ValueKey('active'), workoutsAsync: activeAsync, archived: false, query: _searchQuery),
        ),
      ],
    );
  }
}

class _WorkoutList extends StatelessWidget {
  const _WorkoutList({super.key, required this.workoutsAsync, required this.archived, required this.query});

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
              isImported: w.isImported,
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
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
