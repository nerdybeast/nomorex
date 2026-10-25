import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/my_prs_grouped_provider.dart';
import '../providers/personal_bests_provider.dart';
import '../../../shared/widgets/list_group.dart';
import '../../../shared/widgets/dashboard_empty_state_card.dart';
import '../../../shared/widgets/pr_card.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../utils/estimated_pr_label.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/weight_converter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../profile/providers/profile_provider.dart';

class MyPrsScreen extends ConsumerStatefulWidget {
  const MyPrsScreen({super.key});

  @override
  ConsumerState<MyPrsScreen> createState() => _MyPrsScreenState();
}

class _MyPrsScreenState extends ConsumerState<MyPrsScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final grouped = ref.watch(myPrsGroupedProvider);
    final prsAsync = ref.watch(personalBestsProvider);
    final unit = ref.watch(unitPreferenceProvider);
    final formula = ref.watch(oneRepMaxFormulaProvider);

    // Filter by search query
    final filtered = _searchQuery.isEmpty
        ? grouped
        : Map.fromEntries(
            grouped.entries.where(
              (e) => e.key.toLowerCase().contains(_searchQuery.toLowerCase()),
            ),
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('My PRs'),
        actions: [
          IconButton(
            icon: prsAsync.isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: prsAsync.isRefreshing
                ? null
                : () => ref.read(personalBestsProvider.notifier).refresh(),
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
                hintText: 'Search exercises...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Expanded(
            child: prsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Failed to load PRs: $e',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ),
              data: (_) {
                if (grouped.isEmpty) {
                  return ListView(
                    padding: shellListPadding(context),
                    children: [
                      DashboardEmptyStateCard(
                        icon: Icons.emoji_events_outlined,
                        title: 'No PRs yet.',
                        message: 'Log a personal best to start tracking your progress.',
                        ctaLabel: 'Log your first PR',
                        onCta: () => context.push(AppConstants.routeAddPr),
                      ),
                    ],
                  );
                }
                if (filtered.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No PRs found.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                // Rows in one bordered container rather than a card each.
                return ListView(
                  padding: shellListPadding(context),
                  children: [
                    ListGroup(
                      children: [
                        for (final entry in filtered.entries)
                          // Each value list is sorted by date desc, so first =
                          // most recent.
                          PrCard(
                            exerciseName: entry.key,
                            weightDisplay: formatWeightForPreference(entry.value.first.weightKg, unit),
                            reps: entry.value.first.reps,
                            dateDisplay: formatDate(entry.value.first.date),
                            notes: entry.value.first.notes,
                            notesMaxLines: 2,
                            estimatedOneRepMaxDisplay:
                                estimatedOneRepMaxLabel(entry.value.first, formula, unit),
                            onTap: () =>
                                context.push(AppConstants.routePrHistory(entry.value.first.exerciseId)),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
