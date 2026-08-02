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

String _$workoutsNotifierHash() => r'4bf8138c2bb4cffd4825ea1abb2114cdbec5ff6d';

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
