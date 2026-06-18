import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/personal_best.dart';
import 'personal_bests_provider.dart';

part 'my_prs_grouped_provider.g.dart';

/// Groups all PRs by exercise name, sorted alphabetically.
/// Each group's entries are sorted by date descending.
@riverpod
Map<String, List<PersonalBest>> myPrsGrouped(Ref ref) {
  final all = ref.watch(personalBestsProvider).asData?.value ?? [];
  final map = <String, List<PersonalBest>>{};
  for (final pr in all) {
    map.putIfAbsent(pr.exerciseName, () => []).add(pr);
  }
  // Sort each group by date descending
  for (final list in map.values) {
    list.sort((a, b) => b.date.compareTo(a.date));
  }
  // Return sorted by exercise name
  return Map.fromEntries(
    map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
}
