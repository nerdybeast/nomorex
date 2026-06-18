import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../personal_bests/models/personal_best.dart';
import '../../personal_bests/providers/personal_bests_provider.dart';

part 'dashboard_provider.g.dart';

/// Returns the 5 most recently updated PRs for the dashboard.
/// personalBestsProvider is already ordered by updated_at desc.
@riverpod
List<PersonalBest> dashboardPrs(Ref ref) {
  final all = ref.watch(personalBestsProvider).asData?.value ?? [];
  return all.take(5).toList();
}
