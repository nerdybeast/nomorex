// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'program_instances_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Action-only notifier (no state of its own) for the "Start Program" flow
/// and running-instance status updates — mirrors AuthNotifier's shape.

@ProviderFor(ProgramInstancesNotifier)
final programInstancesProvider = ProgramInstancesNotifierProvider._();

/// Action-only notifier (no state of its own) for the "Start Program" flow
/// and running-instance status updates — mirrors AuthNotifier's shape.
final class ProgramInstancesNotifierProvider
    extends $NotifierProvider<ProgramInstancesNotifier, void> {
  /// Action-only notifier (no state of its own) for the "Start Program" flow
  /// and running-instance status updates — mirrors AuthNotifier's shape.
  ProgramInstancesNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'programInstancesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$programInstancesNotifierHash();

  @$internal
  @override
  ProgramInstancesNotifier create() => ProgramInstancesNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$programInstancesNotifierHash() =>
    r'f032dc6e44bae0b5ffd52ef94e8aea230166867e';

/// Action-only notifier (no state of its own) for the "Start Program" flow
/// and running-instance status updates — mirrors AuthNotifier's shape.

abstract class _$ProgramInstancesNotifier extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
