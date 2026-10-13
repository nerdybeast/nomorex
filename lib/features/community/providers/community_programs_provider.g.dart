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
    extends $AsyncNotifierProvider<CommunityProgramsNotifier, List<Program>> {
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
    r'75d9bdb677328233a9a5144c59f819306d8a8fd6';

/// Public programs authored by *other* users, mirroring
/// [CommunityWorkoutsNotifier]. Shallow like `ProgramsNotifier`: weeks and
/// their day rows only (no exercises or sets), so the list can show week and
/// training-day counts cheaply.

abstract class _$CommunityProgramsNotifier
    extends $AsyncNotifier<List<Program>> {
  FutureOr<List<Program>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Program>>, List<Program>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Program>>, List<Program>>,
              AsyncValue<List<Program>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
