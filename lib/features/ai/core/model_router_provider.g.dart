// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_router_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the on-device model can run. `unsupported` everywhere until the
/// Apple Intelligence (Stage 7) and Gemini Nano / Chrome (Stage 8) plugins
/// report their status here.

@ProviderFor(onDeviceAvailability)
final onDeviceAvailabilityProvider = OnDeviceAvailabilityProvider._();

/// Whether the on-device model can run. `unsupported` everywhere until the
/// Apple Intelligence (Stage 7) and Gemini Nano / Chrome (Stage 8) plugins
/// report their status here.

final class OnDeviceAvailabilityProvider
    extends $FunctionalProvider<OnDeviceStatus, OnDeviceStatus, OnDeviceStatus>
    with $Provider<OnDeviceStatus> {
  /// Whether the on-device model can run. `unsupported` everywhere until the
  /// Apple Intelligence (Stage 7) and Gemini Nano / Chrome (Stage 8) plugins
  /// report their status here.
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
  $ProviderElement<OnDeviceStatus> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  OnDeviceStatus create(Ref ref) {
    return onDeviceAvailability(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OnDeviceStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OnDeviceStatus>(value),
    );
  }
}

String _$onDeviceAvailabilityHash() =>
    r'1a8caa4019105500697993f89ee56453eff76060';

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

String _$modelForTaskHash() => r'52b6249b9ff6f106b57a0236b0e84f0521e4e3d4';

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
