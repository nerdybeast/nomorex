import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/owner_name.dart';
import '../../../shared/widgets/list_group.dart';
import '../../../shared/widgets/dashboard_empty_state_card.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../providers/community_programs_provider.dart';
import '../providers/community_workouts_provider.dart';
import '../widgets/community_cards.dart';

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
        title: const Text('Community'),
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
          // On wide layouts the sidebar's account card opens Profile.
          if (isMobile(context))
            IconButton(
              icon: const Icon(Icons.person_outline),
              tooltip: 'Profile',
              onPressed: () => context.push(AppConstants.routeProfile),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(key: Key('community_tab_programs'), text: 'Programs'),
            Tab(key: Key('community_tab_workouts'), text: 'Workouts'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: contentPadding(context, top: 12, bottom: 0),
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
                _ProgramsTab(query: _searchQuery, colorScheme: colorScheme),
                _WorkoutsTab(query: _searchQuery, colorScheme: colorScheme),
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
          return ListView(
            padding: shellListPadding(context),
            children: const [
              DashboardEmptyStateCard(
                icon: Icons.fitness_center_outlined,
                title: 'No public workouts yet.',
                message: 'Workouts other lifters share will show up here.',
              ),
            ],
          );
        }
        final notifier = ref.read(communityWorkoutsProvider.notifier);
        final filtered =
            workouts.where((w) => _matches(query, w.title, w.ownerDisplayName)).toList();
        return ListView(
          padding: shellListPadding(context),
          children: [
            if (filtered.isEmpty)
              const _NoMatches('No workouts match your search.')
            else
              ListGroup(
                children: [
                  for (final w in filtered)
                    CommunityWorkoutCard(
                      workout: w,
                      onTap: () => context.push(AppConstants.routeCommunityWorkoutDetail(w.id)),
                    ),
                ],
              ),
            if (notifier.hasMore)
              _LoadMore(
                key: const Key('community_workouts_load_more'),
                searching: query.isNotEmpty,
                loadedCount: workouts.length,
                noun: 'workouts',
                onLoadMore: notifier.loadMore,
              ),
          ],
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
          return ListView(
            padding: shellListPadding(context),
            children: const [
              DashboardEmptyStateCard(
                icon: Icons.checklist_outlined,
                title: 'No public programs yet.',
                message: 'Programs other lifters share will show up here.',
              ),
            ],
          );
        }
        final notifier = ref.read(communityProgramsProvider.notifier);
        final filtered =
            programs.where((p) => _matches(query, p.name, p.ownerDisplayName)).toList();
        return ListView(
          padding: shellListPadding(context),
          children: [
            if (filtered.isEmpty)
              const _NoMatches('No programs match your search.')
            else
              ListGroup(
                children: [
                  for (final p in filtered)
                    CommunityProgramCard(
                      program: p,
                      onTap: () => context.push(AppConstants.routeCommunityProgramDetail(p.id)),
                    ),
                ],
              ),
            if (notifier.hasMore)
              _LoadMore(
                key: const Key('community_programs_load_more'),
                searching: query.isNotEmpty,
                loadedCount: programs.length,
                noun: 'programs',
                onLoadMore: notifier.loadMore,
              ),
          ],
        );
      },
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(child: Text(message)),
      );
}

/// The foot of a Community list while more pages exist. Search only covers
/// what's loaded, so while searching it says so rather than implying the
/// matches above are everything.
class _LoadMore extends StatefulWidget {
  const _LoadMore({
    super.key,
    required this.searching,
    required this.loadedCount,
    required this.noun,
    required this.onLoadMore,
  });

  final bool searching;
  final int loadedCount;
  final String noun;
  final Future<void> Function() onLoadMore;

  @override
  State<_LoadMore> createState() => _LoadMoreState();
}

class _LoadMoreState extends State<_LoadMore> {
  bool _busy = false;

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      await widget.onLoadMore();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          if (widget.searching)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Searching the newest ${widget.loadedCount} ${widget.noun}. Load more to search older ones.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.fg3),
              ),
            ),
          FilledButton(
            style: tokens.secondaryButtonStyle,
            onPressed: _busy ? null : _load,
            child: _busy
                ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Load more'),
          ),
        ],
      ),
    );
  }
}
