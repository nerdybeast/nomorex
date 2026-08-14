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

String _$programsNotifierHash() => r'eafd60f9e20114cd719c8e9bc83681f7d44ada11';

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
    r'9419b2da3ecbf24b1724881065ba813b14763db1';

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

/// "Program N" where N is one past the highest numbered program name the
/// user has — including archived ones, since programs are never hard-deleted
/// (see [ArchivedProgramsNotifier]), so a freed-up number could otherwise
/// collide with an existing archived program's name.

@ProviderFor(nextProgramName)
final nextProgramNameProvider = NextProgramNameProvider._();

/// "Program N" where N is one past the highest numbered program name the
/// user has — including archived ones, since programs are never hard-deleted
/// (see [ArchivedProgramsNotifier]), so a freed-up number could otherwise
/// collide with an existing archived program's name.

final class NextProgramNameProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  /// "Program N" where N is one past the highest numbered program name the
  /// user has — including archived ones, since programs are never hard-deleted
  /// (see [ArchivedProgramsNotifier]), so a freed-up number could otherwise
  /// collide with an existing archived program's name.
  NextProgramNameProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nextProgramNameProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nextProgramNameHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return nextProgramName(ref);
  }
}

String _$nextProgramNameHash() => r'859ff9f6b39ceacb2e658db4d309d40643a79149';
