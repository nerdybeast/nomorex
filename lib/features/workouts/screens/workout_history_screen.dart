import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/duration_formatter.dart';
import '../models/workout.dart';
import '../providers/finished_workouts_provider.dart';
import '../utils/workout_timer.dart';

class WorkoutHistoryScreen extends ConsumerStatefulWidget {
  const WorkoutHistoryScreen({super.key, this.initialGroupId});
  final String? initialGroupId;

  @override
  ConsumerState<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends ConsumerState<WorkoutHistoryScreen> {
  String? _filterGroupId;

  @override
  void initState() {
    super.initState();
    _filterGroupId = widget.initialGroupId;
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(finishedWorkoutsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('WORKOUT HISTORY')),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: colorScheme.error))),
        data: (all) {
          if (all.isEmpty) {
            return const Center(child: Text("You haven't completed any workouts yet."));
          }

          final filterGroupId = _filterGroupId;
          final filtered = filterGroupId == null
              ? all
              : all.where((w) => w.workoutGroupId == filterGroupId).toList();
          final filteredTitle = filterGroupId == null
              ? null
              : all.firstWhere((w) => w.workoutGroupId == filterGroupId, orElse: () => all.first).title;

          return Column(
            children: [
              if (filterGroupId != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Filtering: $filteredTitle',
                          style: Theme.of(context).textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _filterGroupId = null),
                        child: const Text('Clear filter'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No completed sessions of this workout yet.'))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          for (final workout in filtered)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _HistoryEntryCard(
                                workout: workout,
                                onTap: () =>
                                    context.push(AppConstants.routeWorkoutDetail(workout.id)),
                              ),
                            ),
                        ],
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
  const _HistoryEntryCard({required this.workout, this.onTap});

  final Workout workout;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleStyle =
        theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final notes = workout.sessionNotes;
    final hasNotes = notes != null && notes.trim().isNotEmpty;
    final duration = formatDuration(computeElapsed(
      startedAt: workout.startedAt!,
      totalPausedSeconds: workout.totalPausedSeconds,
      finishedAt: workout.finishedAt,
    ));

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(workout.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Completed ${formatDate(workout.finishedAt!.toLocal())}', style: subtitleStyle),
              Text('Duration: $duration', style: subtitleStyle),
              const SizedBox(height: 8),
              hasNotes
                  ? Text(notes)
                  : Text(
                      'No Notes Provided',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
