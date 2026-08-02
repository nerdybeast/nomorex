import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_formatter.dart';
import '../providers/workouts_provider.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Workouts')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'workoutsNewFab',
        onPressed: () async {
          final id = await ref.read(workoutsProvider.notifier).createWorkout();
          if (context.mounted) context.push(AppConstants.routeWorkoutEdit(id));
        },
        icon: const Icon(Icons.add),
        label: const Text('New workout'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search workouts...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Expanded(
            child: workoutsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (workouts) {
                if (workouts.isEmpty) {
                  return const Center(child: Text('No workouts yet. Tap "New workout" to start.'));
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
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final w = filtered[i];
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
          ),
        ],
      ),
    );
  }
}
