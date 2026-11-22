// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'community_programs_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Public programs authored by *other* users, mirroring
/// [CommunityWorkoutsNotifier]. Shallow like `ProgramsNotifier`: weeks and
/// their day rows only (no exercises or sets), so the list can show week and
/// training-day counts cheaply.

@ProviderFor(CommunityProgramsNotifier)
final communityProgramsProvider = CommunityProgramsNotifierProvider._();

/// Public programs authored by *other* users, mirroring
/// [CommunityWorkoutsNotifier]. Shallow like `ProgramsNotifier`: weeks and
/// their day rows only (no exercises or sets), so the list can show week and
/// training-day counts cheaply.
final class CommunityProgramsNotifierProvider
    extends
        $AsyncNotifierProvider<
          CommunityProgramsNotifier,
          CommunityPage<Program>
        > {
  /// Public programs authored by *other* users, mirroring
  /// [CommunityWorkoutsNotifier]. Shallow like `ProgramsNotifier`: weeks and
  /// their day rows only (no exercises or sets), so the list can show week and
  /// training-day counts cheaply.
  CommunityProgramsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'communityProgramsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$communityProgramsNotifierHash();

  @$internal
  @override
  CommunityProgramsNotifier create() => CommunityProgramsNotifier();
}

String _$communityProgramsNotifierHash() =>
    r'9f13a0b4a8f7bfef415a952263fdb1e517f07b24';

/// Public programs authored by *other* users, mirroring
/// [CommunityWorkoutsNotifier]. Shallow like `ProgramsNotifier`: weeks and
/// their day rows only (no exercises or sets), so the list can show week and
/// training-day counts cheaply.

abstract class _$CommunityProgramsNotifier
    extends $AsyncNotifier<CommunityPage<Program>> {
  FutureOr<CommunityPage<Program>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<CommunityPage<Program>>, CommunityPage<Program>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<CommunityPage<Program>>,
                CommunityPage<Program>
              >,
              AsyncValue<CommunityPage<Program>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
