import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'finished_workouts_provider.dart';

part 'workout_group_history_provider.g.dart';

/// Whether this workout-group has at least one finished completion —
/// derived from [finishedWorkoutsProvider]'s already-loaded list, mirroring
/// [prHistoryProvider]'s pattern. Drives whether a not-started workout's
/// detail screen offers "Do This Workout Again" instead of plain
/// "Start Workout".
@riverpod
bool groupHasFinishedHistory(Ref ref, String groupId) {
  final all = ref.watch(finishedWorkoutsProvider).asData?.value ?? const [];
  return all.any((w) => w.workoutGroupId == groupId);
}
