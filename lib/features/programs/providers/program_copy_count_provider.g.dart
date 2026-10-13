// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'program_copy_count_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// How many (non-archived) copies of another user's public program the viewer
/// has saved — drives the "You've saved this" hint on the community screen.
/// Invalidated as a whole family by ProgramsNotifier.saveCommunityProgram,
/// archiveProgram and restoreProgram.

@ProviderFor(programCopyCount)
final programCopyCountProvider = ProgramCopyCountFamily._();

/// How many (non-archived) copies of another user's public program the viewer
/// has saved — drives the "You've saved this" hint on the community screen.
/// Invalidated as a whole family by ProgramsNotifier.saveCommunityProgram,
/// archiveProgram and restoreProgram.

final class ProgramCopyCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  /// How many (non-archived) copies of another user's public program the viewer
  /// has saved — drives the "You've saved this" hint on the community screen.
  /// Invalidated as a whole family by ProgramsNotifier.saveCommunityProgram,
  /// archiveProgram and restoreProgram.
  ProgramCopyCountProvider._({
    required ProgramCopyCountFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'programCopyCountProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$programCopyCountHash();

  @override
  String toString() {
    return r'programCopyCountProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    final argument = this.argument as String;
    return programCopyCount(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ProgramCopyCountProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$programCopyCountHash() => r'5ef94bbae123989cd84712737e35bd1eb3c79dee';

/// How many (non-archived) copies of another user's public program the viewer
/// has saved — drives the "You've saved this" hint on the community screen.
/// Invalidated as a whole family by ProgramsNotifier.saveCommunityProgram,
/// archiveProgram and restoreProgram.

final class ProgramCopyCountFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<int>, String> {
  ProgramCopyCountFamily._()
    : super(
        retry: null,
        name: r'programCopyCountProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// How many (non-archived) copies of another user's public program the viewer
  /// has saved — drives the "You've saved this" hint on the community screen.
  /// Invalidated as a whole family by ProgramsNotifier.saveCommunityProgram,
  /// archiveProgram and restoreProgram.

  ProgramCopyCountProvider call(String sourceProgramId) =>
      ProgramCopyCountProvider._(argument: sourceProgramId, from: this);

  @override
  String toString() => r'programCopyCountProvider';
}
