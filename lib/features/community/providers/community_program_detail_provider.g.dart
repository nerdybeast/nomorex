// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'community_program_detail_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Full read-only tree for one public program, mirroring
/// [CommunityWorkoutDetailNotifier]. Deliberately separate from
/// `ProgramDetailNotifier`, which carries every authoring mutation — a viewer
/// looking at someone else's program should have no way to reach those.

@ProviderFor(CommunityProgramDetailNotifier)
final communityProgramDetailProvider = CommunityProgramDetailNotifierFamily._();

/// Full read-only tree for one public program, mirroring
/// [CommunityWorkoutDetailNotifier]. Deliberately separate from
/// `ProgramDetailNotifier`, which carries every authoring mutation — a viewer
/// looking at someone else's program should have no way to reach those.
final class CommunityProgramDetailNotifierProvider
    extends $AsyncNotifierProvider<CommunityProgramDetailNotifier, Program> {
  /// Full read-only tree for one public program, mirroring
  /// [CommunityWorkoutDetailNotifier]. Deliberately separate from
  /// `ProgramDetailNotifier`, which carries every authoring mutation — a viewer
  /// looking at someone else's program should have no way to reach those.
  CommunityProgramDetailNotifierProvider._({
    required CommunityProgramDetailNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'communityProgramDetailProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$communityProgramDetailNotifierHash();

  @override
  String toString() {
    return r'communityProgramDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  CommunityProgramDetailNotifier create() => CommunityProgramDetailNotifier();

  @override
  bool operator ==(Object other) {
    return other is CommunityProgramDetailNotifierProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$communityProgramDetailNotifierHash() =>
    r'2d8b4c0907fa2e01a22e1b29efe644333374585a';

/// Full read-only tree for one public program, mirroring
/// [CommunityWorkoutDetailNotifier]. Deliberately separate from
/// `ProgramDetailNotifier`, which carries every authoring mutation — a viewer
/// looking at someone else's program should have no way to reach those.

final class CommunityProgramDetailNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          CommunityProgramDetailNotifier,
          AsyncValue<Program>,
          Program,
          FutureOr<Program>,
          String
        > {
  CommunityProgramDetailNotifierFamily._()
    : super(
        retry: null,
        name: r'communityProgramDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Full read-only tree for one public program, mirroring
  /// [CommunityWorkoutDetailNotifier]. Deliberately separate from
  /// `ProgramDetailNotifier`, which carries every authoring mutation — a viewer
  /// looking at someone else's program should have no way to reach those.

  CommunityProgramDetailNotifierProvider call(String programId) =>
      CommunityProgramDetailNotifierProvider._(argument: programId, from: this);

  @override
  String toString() => r'communityProgramDetailProvider';
}

/// Full read-only tree for one public program, mirroring
/// [CommunityWorkoutDetailNotifier]. Deliberately separate from
/// `ProgramDetailNotifier`, which carries every authoring mutation — a viewer
/// looking at someone else's program should have no way to reach those.

abstract class _$CommunityProgramDetailNotifier
    extends $AsyncNotifier<Program> {
  late final _$args = ref.$arg as String;
  String get programId => _$args;

  FutureOr<Program> build(String programId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Program>, Program>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Program>, Program>,
              AsyncValue<Program>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
