// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'programs_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ProgramsNotifier)
final programsProvider = ProgramsNotifierProvider._();

final class ProgramsNotifierProvider
    extends $AsyncNotifierProvider<ProgramsNotifier, List<Program>> {
  ProgramsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'programsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$programsNotifierHash();

  @$internal
  @override
  ProgramsNotifier create() => ProgramsNotifier();
}

String _$programsNotifierHash() => r'24a7693ea2782fb864d9d8c31d6d3bbfedf3b7fa';

abstract class _$ProgramsNotifier extends $AsyncNotifier<List<Program>> {
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

/// Mirrors [ProgramsNotifier] but surfaces the archived list, so a user can
/// find and restore a program they archived. No hard delete is ever
/// exposed — see `programs.is_archived` in the Phase 3 migration.

@ProviderFor(ArchivedProgramsNotifier)
final archivedProgramsProvider = ArchivedProgramsNotifierProvider._();

/// Mirrors [ProgramsNotifier] but surfaces the archived list, so a user can
/// find and restore a program they archived. No hard delete is ever
/// exposed — see `programs.is_archived` in the Phase 3 migration.
final class ArchivedProgramsNotifierProvider
    extends $AsyncNotifierProvider<ArchivedProgramsNotifier, List<Program>> {
  /// Mirrors [ProgramsNotifier] but surfaces the archived list, so a user can
  /// find and restore a program they archived. No hard delete is ever
  /// exposed — see `programs.is_archived` in the Phase 3 migration.
  ArchivedProgramsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'archivedProgramsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$archivedProgramsNotifierHash();

  @$internal
  @override
  ArchivedProgramsNotifier create() => ArchivedProgramsNotifier();
}

String _$archivedProgramsNotifierHash() =>
    r'e25217c3a27981ea92ef5cc231a317298847e444';

/// Mirrors [ProgramsNotifier] but surfaces the archived list, so a user can
/// find and restore a program they archived. No hard delete is ever
/// exposed — see `programs.is_archived` in the Phase 3 migration.

abstract class _$ArchivedProgramsNotifier
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
