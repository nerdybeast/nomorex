// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_router_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the on-device model can run, or null when this build has no way to
/// ask: null everywhere until the Apple Intelligence (Stage 7) and Gemini Nano
/// / Chrome (Stage 8) plugins report here. Null is not `unsupported`: the
/// device may well have a model the app can't use yet, so the settings screen
/// says nothing rather than "this device can't run one".

@ProviderFor(onDeviceAvailability)
final onDeviceAvailabilityProvider = OnDeviceAvailabilityProvider._();

/// Whether the on-device model can run, or null when this build has no way to
/// ask: null everywhere until the Apple Intelligence (Stage 7) and Gemini Nano
/// / Chrome (Stage 8) plugins report here. Null is not `unsupported`: the
/// device may well have a model the app can't use yet, so the settings screen
/// says nothing rather than "this device can't run one".

final class OnDeviceAvailabilityProvider
    extends
        $FunctionalProvider<OnDeviceStatus?, OnDeviceStatus?, OnDeviceStatus?>
    with $Provider<OnDeviceStatus?> {
  /// Whether the on-device model can run, or null when this build has no way to
  /// ask: null everywhere until the Apple Intelligence (Stage 7) and Gemini Nano
  /// / Chrome (Stage 8) plugins report here. Null is not `unsupported`: the
  /// device may well have a model the app can't use yet, so the settings screen
  /// says nothing rather than "this device can't run one".
  OnDeviceAvailabilityProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'onDeviceAvailabilityProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onDeviceAvailabilityHash();

  @$internal
  @override
  $ProviderElement<OnDeviceStatus?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  OnDeviceStatus? create(Ref ref) {
    return onDeviceAvailability(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OnDeviceStatus? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OnDeviceStatus?>(value),
    );
  }
}

String _$onDeviceAvailabilityHash() =>
    r'9238d2971104b7c7e6f515c9bff1ada8cc2267b2';

/// Which model runs [task] right now, or null when nothing can: the feature
/// hides itself then. Also null while the settings are still loading, so a
/// feature appears once they have.

@ProviderFor(modelForTask)
final modelForTaskProvider = ModelForTaskFamily._();

/// Which model runs [task] right now, or null when nothing can: the feature
/// hides itself then. Also null while the settings are still loading, so a
/// feature appears once they have.

final class ModelForTaskProvider
    extends $FunctionalProvider<AiRoute?, AiRoute?, AiRoute?>
    with $Provider<AiRoute?> {
  /// Which model runs [task] right now, or null when nothing can: the feature
  /// hides itself then. Also null while the settings are still loading, so a
  /// feature appears once they have.
  ModelForTaskProvider._({
    required ModelForTaskFamily super.from,
    required AiTask super.argument,
  }) : super(
         retry: null,
         name: r'modelForTaskProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$modelForTaskHash();

  @override
  String toString() {
    return r'modelForTaskProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<AiRoute?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AiRoute? create(Ref ref) {
    final argument = this.argument as AiTask;
    return modelForTask(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiRoute? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AiRoute?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ModelForTaskProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$modelForTaskHash() => r'a91b6c3b330b2ef5134c1844f462f4f0b1a8ad8e';

/// Which model runs [task] right now, or null when nothing can: the feature
/// hides itself then. Also null while the settings are still loading, so a
/// feature appears once they have.

final class ModelForTaskFamily extends $Family
    with $FunctionalFamilyOverride<AiRoute?, AiTask> {
  ModelForTaskFamily._()
    : super(
        retry: null,
        name: r'modelForTaskProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Which model runs [task] right now, or null when nothing can: the feature
  /// hides itself then. Also null while the settings are still loading, so a
  /// feature appears once they have.

  ModelForTaskProvider call(AiTask task) =>
      ModelForTaskProvider._(argument: task, from: this);

  @override
  String toString() => r'modelForTaskProvider';
}
