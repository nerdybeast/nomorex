// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workouts_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(WorkoutsNotifier)
final workoutsProvider = WorkoutsNotifierProvider._();

final class WorkoutsNotifierProvider
    extends $AsyncNotifierProvider<WorkoutsNotifier, List<Workout>> {
  WorkoutsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workoutsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workoutsNotifierHash();

  @$internal
  @override
  WorkoutsNotifier create() => WorkoutsNotifier();
}

String _$workoutsNotifierHash() => r'094a3b9e37c2053919f1ddc860e5ba559bbdaed7';

abstract class _$WorkoutsNotifier extends $AsyncNotifier<List<Workout>> {
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

/// "Workout N" where N is one past the highest numbered workout title the
/// user has, across all their workouts (including ones materialized from a
/// program), so a freed-up number can't collide with an existing title.

@ProviderFor(nextWorkoutName)
final nextWorkoutNameProvider = NextWorkoutNameProvider._();

/// "Workout N" where N is one past the highest numbered workout title the
/// user has, across all their workouts (including ones materialized from a
/// program), so a freed-up number can't collide with an existing title.

final class NextWorkoutNameProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  /// "Workout N" where N is one past the highest numbered workout title the
  /// user has, across all their workouts (including ones materialized from a
  /// program), so a freed-up number can't collide with an existing title.
  NextWorkoutNameProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nextWorkoutNameProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nextWorkoutNameHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return nextWorkoutName(ref);
  }
}

String _$nextWorkoutNameHash() => r'd60760d6bf1a6b70f0466247b7c39177d846a7b8';
