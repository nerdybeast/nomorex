// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_router_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The bridge to Apple's Foundation Models, as a provider so tests can fake it.

@ProviderFor(appleIntelligence)
final appleIntelligenceProvider = AppleIntelligenceProvider._();

/// The bridge to Apple's Foundation Models, as a provider so tests can fake it.

final class AppleIntelligenceProvider
    extends
        $FunctionalProvider<
          AppleIntelligenceApi,
          AppleIntelligenceApi,
          AppleIntelligenceApi
        >
    with $Provider<AppleIntelligenceApi> {
  /// The bridge to Apple's Foundation Models, as a provider so tests can fake it.
  AppleIntelligenceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appleIntelligenceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appleIntelligenceHash();

  @$internal
  @override
  $ProviderElement<AppleIntelligenceApi> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AppleIntelligenceApi create(Ref ref) {
    return appleIntelligence(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppleIntelligenceApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppleIntelligenceApi>(value),
    );
  }
}

String _$appleIntelligenceHash() => r'7ea429244251859ec2a88cf4e7ca51d4e7042f3d';

/// Apple Intelligence's status on iOS and macOS, or null on other platforms.
/// Re-read when the app resumes (`AiImportJobAlerts`), since the lifter may
/// have turned Apple Intelligence on in Settings meanwhile.

@ProviderFor(appleModelStatus)
final appleModelStatusProvider = AppleModelStatusProvider._();

/// Apple Intelligence's status on iOS and macOS, or null on other platforms.
/// Re-read when the app resumes (`AiImportJobAlerts`), since the lifter may
/// have turned Apple Intelligence on in Settings meanwhile.

final class AppleModelStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<AppleModelStatus?>,
          AppleModelStatus?,
          FutureOr<AppleModelStatus?>
        >
    with
        $FutureModifier<AppleModelStatus?>,
        $FutureProvider<AppleModelStatus?> {
  /// Apple Intelligence's status on iOS and macOS, or null on other platforms.
  /// Re-read when the app resumes (`AiImportJobAlerts`), since the lifter may
  /// have turned Apple Intelligence on in Settings meanwhile.
  AppleModelStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appleModelStatusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appleModelStatusHash();

  @$internal
  @override
  $FutureProviderElement<AppleModelStatus?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AppleModelStatus?> create(Ref ref) {
    return appleModelStatus(ref);
  }
}

String _$appleModelStatusHash() => r'd35ebc277ff2b367c17c7263d761ced016c75d0c';

/// The bridge to ML Kit's Gemini Nano, as a provider so tests can fake it.

@ProviderFor(mlKitGenAi)
final mlKitGenAiProvider = MlKitGenAiProvider._();

/// The bridge to ML Kit's Gemini Nano, as a provider so tests can fake it.

final class MlKitGenAiProvider
    extends $FunctionalProvider<MlKitGenAiApi, MlKitGenAiApi, MlKitGenAiApi>
    with $Provider<MlKitGenAiApi> {
  /// The bridge to ML Kit's Gemini Nano, as a provider so tests can fake it.
  MlKitGenAiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mlKitGenAiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mlKitGenAiHash();

  @$internal
  @override
  $ProviderElement<MlKitGenAiApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MlKitGenAiApi create(Ref ref) {
    return mlKitGenAi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MlKitGenAiApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MlKitGenAiApi>(value),
    );
  }
}

String _$mlKitGenAiHash() => r'b2eb615e27441fc8bfb227c0f13945201f6bfcdd';

/// Gemini Nano's status in the Android app, or null on other platforms. While
/// it's downloading it's re-read every few seconds, which is how the settings
/// screen's progress bar moves and how the model appears once it's done.

@ProviderFor(mlKitModelStatus)
final mlKitModelStatusProvider = MlKitModelStatusProvider._();

/// Gemini Nano's status in the Android app, or null on other platforms. While
/// it's downloading it's re-read every few seconds, which is how the settings
/// screen's progress bar moves and how the model appears once it's done.

final class MlKitModelStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<MlKitModelStatus?>,
          MlKitModelStatus?,
          FutureOr<MlKitModelStatus?>
        >
    with
        $FutureModifier<MlKitModelStatus?>,
        $FutureProvider<MlKitModelStatus?> {
  /// Gemini Nano's status in the Android app, or null on other platforms. While
  /// it's downloading it's re-read every few seconds, which is how the settings
  /// screen's progress bar moves and how the model appears once it's done.
  MlKitModelStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mlKitModelStatusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mlKitModelStatusHash();

  @$internal
  @override
  $FutureProviderElement<MlKitModelStatus?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MlKitModelStatus?> create(Ref ref) {
    return mlKitModelStatus(ref);
  }
}

String _$mlKitModelStatusHash() => r'56fed257ac421c6e7e1e12193e755c78ef819874';

/// The browser's Prompt API, as a provider so tests can fake it.

@ProviderFor(chromeAi)
final chromeAiProvider = ChromeAiProvider._();

/// The browser's Prompt API, as a provider so tests can fake it.

final class ChromeAiProvider
    extends $FunctionalProvider<ChromeAiApi, ChromeAiApi, ChromeAiApi>
    with $Provider<ChromeAiApi> {
  /// The browser's Prompt API, as a provider so tests can fake it.
  ChromeAiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chromeAiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chromeAiHash();

  @$internal
  @override
  $ProviderElement<ChromeAiApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ChromeAiApi create(Ref ref) {
    return chromeAi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChromeAiApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChromeAiApi>(value),
    );
  }
}

String _$chromeAiHash() => r'55c80b66dc1c50f2e04cc647dd7ac2fcc51ca295';

/// Chrome's built-in AI availability on the web, or null in the apps. Re-read
/// every few seconds while Chrome downloads the model.

@ProviderFor(chromeAiAvailability)
final chromeAiAvailabilityProvider = ChromeAiAvailabilityProvider._();

/// Chrome's built-in AI availability on the web, or null in the apps. Re-read
/// every few seconds while Chrome downloads the model.

final class ChromeAiAvailabilityProvider
    extends
        $FunctionalProvider<
          AsyncValue<ChromeAiAvailability?>,
          ChromeAiAvailability?,
          FutureOr<ChromeAiAvailability?>
        >
    with
        $FutureModifier<ChromeAiAvailability?>,
        $FutureProvider<ChromeAiAvailability?> {
  /// Chrome's built-in AI availability on the web, or null in the apps. Re-read
  /// every few seconds while Chrome downloads the model.
  ChromeAiAvailabilityProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chromeAiAvailabilityProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chromeAiAvailabilityHash();

  @$internal
  @override
  $FutureProviderElement<ChromeAiAvailability?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ChromeAiAvailability?> create(Ref ref) {
    return chromeAiAvailability(ref);
  }
}

String _$chromeAiAvailabilityHash() =>
    r'3be6887b284414afd25cdfb447edcd0d7b3ca9d9';

/// Starts the on-device model download. On Android ML Kit runs it and
/// [mlKitModelStatusProvider] follows it; on the web Chrome downloads while the
/// session is created, which needs the click that started it.

@ProviderFor(OnDeviceDownloadNotifier)
final onDeviceDownloadProvider = OnDeviceDownloadNotifierProvider._();

/// Starts the on-device model download. On Android ML Kit runs it and
/// [mlKitModelStatusProvider] follows it; on the web Chrome downloads while the
/// session is created, which needs the click that started it.
final class OnDeviceDownloadNotifierProvider
    extends $NotifierProvider<OnDeviceDownloadNotifier, OnDeviceDownload> {
  /// Starts the on-device model download. On Android ML Kit runs it and
  /// [mlKitModelStatusProvider] follows it; on the web Chrome downloads while the
  /// session is created, which needs the click that started it.
  OnDeviceDownloadNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'onDeviceDownloadProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onDeviceDownloadNotifierHash();

  @$internal
  @override
  OnDeviceDownloadNotifier create() => OnDeviceDownloadNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OnDeviceDownload value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OnDeviceDownload>(value),
    );
  }
}

String _$onDeviceDownloadNotifierHash() =>
    r'e0083bc6bb066d6a06641c9028139643d4a5c1a5';

/// Starts the on-device model download. On Android ML Kit runs it and
/// [mlKitModelStatusProvider] follows it; on the web Chrome downloads while the
/// session is created, which needs the click that started it.

abstract class _$OnDeviceDownloadNotifier extends $Notifier<OnDeviceDownload> {
  OnDeviceDownload build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<OnDeviceDownload, OnDeviceDownload>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<OnDeviceDownload, OnDeviceDownload>,
              OnDeviceDownload,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Whether the on-device model can run here, from whichever platform this is:
/// Apple Intelligence (iOS, macOS), Gemini Nano (Android) or Chrome's built-in
/// AI (web). Null where there's none to ask (Linux, Windows) and while the
/// status loads. Null is not `unsupported`: the settings screen says nothing
/// rather than "this device can't run one".

@ProviderFor(onDeviceAvailability)
final onDeviceAvailabilityProvider = OnDeviceAvailabilityProvider._();

/// Whether the on-device model can run here, from whichever platform this is:
/// Apple Intelligence (iOS, macOS), Gemini Nano (Android) or Chrome's built-in
/// AI (web). Null where there's none to ask (Linux, Windows) and while the
/// status loads. Null is not `unsupported`: the settings screen says nothing
/// rather than "this device can't run one".

final class OnDeviceAvailabilityProvider
    extends
        $FunctionalProvider<OnDeviceStatus?, OnDeviceStatus?, OnDeviceStatus?>
    with $Provider<OnDeviceStatus?> {
  /// Whether the on-device model can run here, from whichever platform this is:
  /// Apple Intelligence (iOS, macOS), Gemini Nano (Android) or Chrome's built-in
  /// AI (web). Null where there's none to ask (Linux, Windows) and while the
  /// status loads. Null is not `unsupported`: the settings screen says nothing
  /// rather than "this device can't run one".
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
    r'9e74e83b71591050d2023bcfacb539e5fcd8cc93';

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
