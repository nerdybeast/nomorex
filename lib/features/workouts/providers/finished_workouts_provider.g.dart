// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'finished_workouts_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every finished workout for the current user, newest completion first —
/// backs both the dashboard's "Recent Workouts" section and the Workout
/// History screen (filtered client-side by workoutGroupId there). Unlike
/// [workoutsProvider], this deliberately does NOT exclude workouts
/// materialized from a program: a completed program-day workout is still a
/// completed workout for history/dashboard purposes.

@ProviderFor(FinishedWorkoutsNotifier)
final finishedWorkoutsProvider = FinishedWorkoutsNotifierProvider._();

/// Every finished workout for the current user, newest completion first —
/// backs both the dashboard's "Recent Workouts" section and the Workout
/// History screen (filtered client-side by workoutGroupId there). Unlike
/// [workoutsProvider], this deliberately does NOT exclude workouts
/// materialized from a program: a completed program-day workout is still a
/// completed workout for history/dashboard purposes.
final class FinishedWorkoutsNotifierProvider
    extends $AsyncNotifierProvider<FinishedWorkoutsNotifier, List<Workout>> {
  /// Every finished workout for the current user, newest completion first —
  /// backs both the dashboard's "Recent Workouts" section and the Workout
  /// History screen (filtered client-side by workoutGroupId there). Unlike
  /// [workoutsProvider], this deliberately does NOT exclude workouts
  /// materialized from a program: a completed program-day workout is still a
  /// completed workout for history/dashboard purposes.
  FinishedWorkoutsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'finishedWorkoutsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$finishedWorkoutsNotifierHash();

  @$internal
  @override
  FinishedWorkoutsNotifier create() => FinishedWorkoutsNotifier();
}

String _$finishedWorkoutsNotifierHash() =>
    r'd7c17958ea0f5dc5ff86b2bff67cf49eeee64fe4';

/// Every finished workout for the current user, newest completion first —
/// backs both the dashboard's "Recent Workouts" section and the Workout
/// History screen (filtered client-side by workoutGroupId there). Unlike
/// [workoutsProvider], this deliberately does NOT exclude workouts
/// materialized from a program: a completed program-day workout is still a
/// completed workout for history/dashboard purposes.

abstract class _$FinishedWorkoutsNotifier
    extends $AsyncNotifier<List<Workout>> {
  FutureOr<List<Workout>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Workout>>, List<Workout>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Workout>>, List<Workout>>,
              AsyncValue<List<Workout>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
