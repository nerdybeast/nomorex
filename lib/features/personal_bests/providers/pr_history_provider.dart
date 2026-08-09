import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/personal_best.dart';
import 'personal_bests_provider.dart';

part 'pr_history_provider.g.dart';

/// Every PR entry logged for one exercise, sorted by date descending.
@riverpod
List<PersonalBest> prHistory(Ref ref, String exerciseId) {
  final all = ref.watch(personalBestsProvider).asData?.value ?? [];
  final history = all.where((pr) => pr.exerciseId == exerciseId).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  return history;
}
