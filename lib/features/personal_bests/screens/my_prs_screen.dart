import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/my_prs_grouped_provider.dart';
import '../providers/personal_bests_provider.dart';
import '../../../shared/widgets/pr_card.dart';
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
        title: const Text('MY PRS'),
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
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final entry = filtered.entries.elementAt(index);
                    final exerciseName = entry.key;
                    final prs = entry.value;
                    final best = prs.first; // sorted by date desc, first = most recent

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: PrCard(
                        exerciseName: exerciseName,
                        weightDisplay: formatWeightForPreference(best.weightKg, unit),
                        reps: best.reps,
                        dateDisplay: formatDate(best.date),
                        notes: best.notes,
                        notesMaxLines: 2,
                        onTap: () => context.push(AppConstants.routePrHistory(best.exerciseId)),
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
