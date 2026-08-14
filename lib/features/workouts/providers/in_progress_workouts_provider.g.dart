// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'in_progress_workouts_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Workouts currently in progress or paused for the current user — what the
/// dashboard's "Workouts In Progress" section reads from. Unlike
/// [workoutsProvider], this deliberately does NOT exclude workouts
/// materialized from a program: a program-originated workout that's
/// actively in progress should still surface on the dashboard.

@ProviderFor(InProgressWorkoutsNotifier)
final inProgressWorkoutsProvider = InProgressWorkoutsNotifierProvider._();

/// Workouts currently in progress or paused for the current user — what the
/// dashboard's "Workouts In Progress" section reads from. Unlike
/// [workoutsProvider], this deliberately does NOT exclude workouts
/// materialized from a program: a program-originated workout that's
/// actively in progress should still surface on the dashboard.
final class InProgressWorkoutsNotifierProvider
    extends $AsyncNotifierProvider<InProgressWorkoutsNotifier, List<Workout>> {
  /// Workouts currently in progress or paused for the current user — what the
  /// dashboard's "Workouts In Progress" section reads from. Unlike
  /// [workoutsProvider], this deliberately does NOT exclude workouts
  /// materialized from a program: a program-originated workout that's
  /// actively in progress should still surface on the dashboard.
  InProgressWorkoutsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inProgressWorkoutsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inProgressWorkoutsNotifierHash();

  @$internal
  @override
  InProgressWorkoutsNotifier create() => InProgressWorkoutsNotifier();
}

String _$inProgressWorkoutsNotifierHash() =>
    r'79e6e91074fba9f54c177f445192d2b7aa3d5283';

/// Workouts currently in progress or paused for the current user — what the
/// dashboard's "Workouts In Progress" section reads from. Unlike
/// [workoutsProvider], this deliberately does NOT exclude workouts
/// materialized from a program: a program-originated workout that's
/// actively in progress should still surface on the dashboard.

abstract class _$InProgressWorkoutsNotifier
    extends $AsyncNotifier<List<Workout>> {
  FutureOr<List<Workout>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Workout>>, List<Workout>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Workout>>, List<Workout>>,
              AsyncValue<List<Workout>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
