// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'program_instances_list_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Active program runs for the current user — what the dashboard's "Current
/// Programs" section reads from. Excludes completed/abandoned instances.

@ProviderFor(CurrentProgramInstancesNotifier)
final currentProgramInstancesProvider =
    CurrentProgramInstancesNotifierProvider._();

/// Active program runs for the current user — what the dashboard's "Current
/// Programs" section reads from. Excludes completed/abandoned instances.
final class CurrentProgramInstancesNotifierProvider
    extends
        $AsyncNotifierProvider<
          CurrentProgramInstancesNotifier,
          List<ProgramInstance>
        > {
  /// Active program runs for the current user — what the dashboard's "Current
  /// Programs" section reads from. Excludes completed/abandoned instances.
  CurrentProgramInstancesNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentProgramInstancesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentProgramInstancesNotifierHash();

  @$internal
  @override
  CurrentProgramInstancesNotifier create() => CurrentProgramInstancesNotifier();
}

String _$currentProgramInstancesNotifierHash() =>
    r'b1831400778694f22a56ea0f5be1b06d1775316c';

/// Active program runs for the current user — what the dashboard's "Current
/// Programs" section reads from. Excludes completed/abandoned instances.

abstract class _$CurrentProgramInstancesNotifier
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
