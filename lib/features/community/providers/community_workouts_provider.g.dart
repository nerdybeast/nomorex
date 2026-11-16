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
    extends
        $AsyncNotifierProvider<
          CommunityWorkoutsNotifier,
          CommunityPage<Workout>
        > {
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
    r'665923a3ee3f283a6c198c62b18459009bccdd36';

abstract class _$CommunityWorkoutsNotifier
    extends $AsyncNotifier<CommunityPage<Workout>> {
  FutureOr<CommunityPage<Workout>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<CommunityPage<Workout>>, CommunityPage<Workout>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<CommunityPage<Workout>>,
                CommunityPage<Workout>
              >,
              AsyncValue<CommunityPage<Workout>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
