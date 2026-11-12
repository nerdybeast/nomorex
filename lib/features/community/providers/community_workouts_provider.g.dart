// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'community_workouts_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CommunityWorkoutsNotifier)
final communityWorkoutsProvider = CommunityWorkoutsNotifierProvider._();

final class CommunityWorkoutsNotifierProvider
    extends $AsyncNotifierProvider<CommunityWorkoutsNotifier, List<Workout>> {
  CommunityWorkoutsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'communityWorkoutsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$communityWorkoutsNotifierHash();

  @$internal
  @override
  CommunityWorkoutsNotifier create() => CommunityWorkoutsNotifier();
}

String _$communityWorkoutsNotifierHash() =>
    r'd88e7f62630cee5a936622b965a0e528d5b6d69b';

abstract class _$CommunityWorkoutsNotifier
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
