// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'finished_program_instances_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every ended (completed or abandoned) program run for the current user,
/// most recently ended first — backs the Program History screen. Mirror of
/// [CurrentProgramInstancesNotifier], which holds the active runs.

@ProviderFor(FinishedProgramInstancesNotifier)
final finishedProgramInstancesProvider =
    FinishedProgramInstancesNotifierProvider._();

/// Every ended (completed or abandoned) program run for the current user,
/// most recently ended first — backs the Program History screen. Mirror of
/// [CurrentProgramInstancesNotifier], which holds the active runs.
final class FinishedProgramInstancesNotifierProvider
    extends
        $AsyncNotifierProvider<
          FinishedProgramInstancesNotifier,
          List<ProgramInstance>
        > {
  /// Every ended (completed or abandoned) program run for the current user,
  /// most recently ended first — backs the Program History screen. Mirror of
  /// [CurrentProgramInstancesNotifier], which holds the active runs.
  FinishedProgramInstancesNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'finishedProgramInstancesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$finishedProgramInstancesNotifierHash();

  @$internal
  @override
  FinishedProgramInstancesNotifier create() =>
      FinishedProgramInstancesNotifier();
}

String _$finishedProgramInstancesNotifierHash() =>
    r'070d8cc534adf6caaca3b333c853f0a101ccb232';

/// Every ended (completed or abandoned) program run for the current user,
/// most recently ended first — backs the Program History screen. Mirror of
/// [CurrentProgramInstancesNotifier], which holds the active runs.

abstract class _$FinishedProgramInstancesNotifier
    extends $AsyncNotifier<List<ProgramInstance>> {
  FutureOr<List<ProgramInstance>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<ProgramInstance>>, List<ProgramInstance>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<ProgramInstance>>,
                List<ProgramInstance>
              >,
              AsyncValue<List<ProgramInstance>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
