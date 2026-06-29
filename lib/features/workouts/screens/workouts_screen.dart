import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_formatter.dart';
import '../providers/workouts_provider.dart';

class WorkoutsScreen extends ConsumerWidget {
  const WorkoutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutsAsync = ref.watch(workoutsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Workouts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppConstants.routeWorkoutNew),
        icon: const Icon(Icons.add),
        label: const Text('New workout'),
      ),
      body: workoutsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (workouts) {
          if (workouts.isEmpty) {
            return const Center(child: Text('No workouts yet. Tap "New workout" to start.'));
          }
          return ListView.builder(
            itemCount: workouts.length,
            itemBuilder: (context, i) {
              final w = workouts[i];
              return ListTile(
                title: Text(w.title),
                subtitle: Text('${formatDate(w.date)} · ${w.exercises.length} exercises'),
                onTap: () => context.push(AppConstants.routeWorkoutDetail(w.id)),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    final notifier = ref.read(workoutsProvider.notifier);
                    if (value == 'duplicate') {
                      await notifier.duplicateWorkout(w.id);
                    } else if (value == 'edit') {
                      if (context.mounted) context.push(AppConstants.routeWorkoutEdit(w.id));
                    } else if (value == 'delete') {
                      await notifier.deleteWorkout(w.id);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
