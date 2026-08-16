// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'community_programs_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Public programs authored by *other* users, mirroring
/// [CommunityWorkoutsNotifier]. Shallow like `ProgramsNotifier`: weeks only, so
/// the list can show a "N weeks" summary without pulling every day and set.

@ProviderFor(CommunityProgramsNotifier)
final communityProgramsProvider = CommunityProgramsNotifierProvider._();

/// Public programs authored by *other* users, mirroring
/// [CommunityWorkoutsNotifier]. Shallow like `ProgramsNotifier`: weeks only, so
/// the list can show a "N weeks" summary without pulling every day and set.
final class CommunityProgramsNotifierProvider
    extends $AsyncNotifierProvider<CommunityProgramsNotifier, List<Program>> {
  /// Public programs authored by *other* users, mirroring
  /// [CommunityWorkoutsNotifier]. Shallow like `ProgramsNotifier`: weeks only, so
  /// the list can show a "N weeks" summary without pulling every day and set.
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
    r'd814ee3632eb8bb0665a3e99e51138a36ffa871f';

/// Public programs authored by *other* users, mirroring
/// [CommunityWorkoutsNotifier]. Shallow like `ProgramsNotifier`: weeks only, so
/// the list can show a "N weeks" summary without pulling every day and set.

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
