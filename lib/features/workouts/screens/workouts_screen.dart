import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/dashboard_empty_state_card.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../shared/widgets/summary_card.dart';
import '../models/workout.dart';
import '../providers/workouts_provider.dart';
import '../utils/confirm_delete_workout.dart';

class WorkoutsScreen extends ConsumerStatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  ConsumerState<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends ConsumerState<WorkoutsScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final workoutsAsync = ref.watch(workoutsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('WORKOUTS'),
        actions: [
          IconButton(
            icon: workoutsAsync.isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: workoutsAsync.isRefreshing
                ? null
                : () => ref.read(workoutsProvider.notifier).refresh(),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Workout History',
            onPressed: () => context.push(AppConstants.routeWorkoutHistory),
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
                hintText: 'Search workouts...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Expanded(
            child: workoutsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: colorScheme.error))),
              data: (workouts) {
                if (workouts.isEmpty) {
                  return ListView(
                    padding: shellListPadding(context),
                    children: [
                      DashboardEmptyStateCard(
                        icon: Icons.fitness_center_outlined,
                        title: 'No workouts yet.',
                        message: 'Create a workout to start logging your training.',
                        ctaLabel: 'Create your first workout',
                        onCta: () => context.push(AppConstants.routeWorkoutNew),
                      ),
                    ],
                  );
                }
                final filtered = _searchQuery.isEmpty
                    ? workouts
                    : workouts
                        .where((w) => w.title.toLowerCase().contains(_searchQuery.toLowerCase()))
                        .toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('No workouts match your search.'));
                }
                return ListView.builder(
                  padding: shellListPadding(context),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final w = filtered[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _WorkoutTile(workout: w),
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
      body: text == null || text.isEmpty
          ? null
          : Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
      status: statusLabel == null
          ? null
          : Text(
              statusLabel,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
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
          } else if (value == 'delete') {
            await confirmAndDeleteWorkout(context, ref, w);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }
}
