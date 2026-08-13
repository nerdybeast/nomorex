import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_formatter.dart';
import '../providers/community_workouts_provider.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final workoutsAsync = ref.watch(communityWorkoutsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('COMMUNITY'),
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
                : () => ref.read(communityWorkoutsProvider.notifier).refresh(),
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
                hintText: 'Search public workouts...',
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
                  return const Center(child: Text('No public workouts yet.'));
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
                      onTap: () => context.push(AppConstants.routeCommunityWorkoutDetail(w.id)),
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
