import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/owner_name.dart';
import '../providers/community_programs_provider.dart';
import '../providers/community_workouts_provider.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  late final TabController _tabController = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workoutsAsync = ref.watch(communityWorkoutsProvider);
    final programsAsync = ref.watch(communityProgramsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isRefreshing = workoutsAsync.isRefreshing || programsAsync.isRefreshing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('COMMUNITY'),
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
                    ref.read(communityWorkoutsProvider.notifier).refresh();
                    ref.read(communityProgramsProvider.notifier).refresh();
                  },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () => context.push(AppConstants.routeProfile),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(key: Key('community_tab_workouts'), text: 'Workouts'),
            Tab(key: Key('community_tab_programs'), text: 'Programs'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              key: const Key('community_search'),
              decoration: const InputDecoration(
                hintText: 'Search by name or author...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _WorkoutsTab(query: _searchQuery, colorScheme: colorScheme),
                _ProgramsTab(query: _searchQuery, colorScheme: colorScheme),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One search box drives both tabs, and each tab matches on its own title plus
/// the author — finding "everything BeastModeB posted" is as natural a search
/// here as finding a workout by name.
bool _matches(String query, String title, String? owner) {
  if (query.isEmpty) return true;
  final q = query.toLowerCase();
  return title.toLowerCase().contains(q) ||
      ownerDisplayName(owner).toLowerCase().contains(q);
}

class _WorkoutsTab extends ConsumerWidget {
  const _WorkoutsTab({required this.query, required this.colorScheme});

  final String query;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutsAsync = ref.watch(communityWorkoutsProvider);

    return workoutsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: colorScheme.error))),
      data: (workouts) {
        if (workouts.isEmpty) {
          return const Center(child: Text('No public workouts yet.'));
        }
        final filtered =
            workouts.where((w) => _matches(query, w.title, w.ownerDisplayName)).toList();
        if (filtered.isEmpty) {
          return const Center(child: Text('No workouts match your search.'));
        }
        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final w = filtered[i];
            return ListTile(
              title: Text(w.title),
              subtitle: Text(
                'by ${ownerDisplayName(w.ownerDisplayName)} · '
                '${formatDate(w.date)} · ${w.exercises.length} exercises',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppConstants.routeCommunityWorkoutDetail(w.id)),
            );
          },
        );
      },
    );
  }
}

class _ProgramsTab extends ConsumerWidget {
  const _ProgramsTab({required this.query, required this.colorScheme});

  final String query;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programsAsync = ref.watch(communityProgramsProvider);

    return programsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: colorScheme.error))),
      data: (programs) {
        if (programs.isEmpty) {
          return const Center(child: Text('No public programs yet.'));
        }
        final filtered =
            programs.where((p) => _matches(query, p.name, p.ownerDisplayName)).toList();
        if (filtered.isEmpty) {
          return const Center(child: Text('No programs match your search.'));
        }
        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final p = filtered[i];
            final weeks = p.weeks.length;
            return ListTile(
              title: Text(p.name),
              subtitle: Text(
                'by ${ownerDisplayName(p.ownerDisplayName)} · '
                '$weeks ${weeks == 1 ? 'week' : 'weeks'}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppConstants.routeCommunityProgramDetail(p.id)),
            );
          },
        );
      },
    );
  }
}
