import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/my_prs_grouped_provider.dart';
import '../providers/personal_bests_provider.dart';
import '../../../shared/widgets/pr_card.dart';
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
      appBar: AppBar(title: const Text('My PRs')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search exercises...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
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
                  child: Text('Failed to load PRs: $e', textAlign: TextAlign.center),
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
                      child: ExpansionTile(
                        title: Text(
                          exerciseName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${formatWeight(best.weightKg, unit)} × ${best.reps} rep${best.reps == 1 ? '' : 's'} — ${formatDate(best.date)}',
                        ),
                        children: prs.map((pr) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: PrCard(
                              exerciseName: pr.exerciseName,
                              weightDisplay: formatWeight(pr.weightKg, unit),
                              reps: pr.reps,
                              dateDisplay: formatDate(pr.date),
                            ),
                          );
                        }).toList(),
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
