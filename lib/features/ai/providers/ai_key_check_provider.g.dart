// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_key_check_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Overridden in tests so nothing reaches a provider.

@ProviderFor(aiKeyChecker)
final aiKeyCheckerProvider = AiKeyCheckerProvider._();

/// Overridden in tests so nothing reaches a provider.

final class AiKeyCheckerProvider
    extends $FunctionalProvider<AiKeyChecker, AiKeyChecker, AiKeyChecker>
    with $Provider<AiKeyChecker> {
  /// Overridden in tests so nothing reaches a provider.
  AiKeyCheckerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiKeyCheckerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiKeyCheckerHash();

  @$internal
  @override
  $ProviderElement<AiKeyChecker> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AiKeyChecker create(Ref ref) {
    return aiKeyChecker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiKeyChecker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AiKeyChecker>(value),
    );
  }
}

String _$aiKeyCheckerHash() => r'82a1b0490627164daf888a0aeff0522cd0be2b09';

/// Saves, tests and removes keys for the settings screen, and remembers the
/// last check per provider until the screen closes.

@ProviderFor(AiKeyCheckNotifier)
final aiKeyCheckProvider = AiKeyCheckNotifierProvider._();

/// Saves, tests and removes keys for the settings screen, and remembers the
/// last check per provider until the screen closes.
final class AiKeyCheckNotifierProvider
    extends
        $NotifierProvider<AiKeyCheckNotifier, Map<CloudAiProvider, KeyCheck>> {
  /// Saves, tests and removes keys for the settings screen, and remembers the
  /// last check per provider until the screen closes.
  AiKeyCheckNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiKeyCheckProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiKeyCheckNotifierHash();

  @$internal
  @override
  AiKeyCheckNotifier create() => AiKeyCheckNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<CloudAiProvider, KeyCheck> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<CloudAiProvider, KeyCheck>>(
        value,
      ),
    );
  }
}

String _$aiKeyCheckNotifierHash() =>
    r'c45d2c25f2bb1493090efc7caa9207adaa4f0832';

/// Saves, tests and removes keys for the settings screen, and remembers the
/// last check per provider until the screen closes.

abstract class _$AiKeyCheckNotifier
    extends $Notifier<Map<CloudAiProvider, KeyCheck>> {
  Map<CloudAiProvider, KeyCheck> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              Map<CloudAiProvider, KeyCheck>,
              Map<CloudAiProvider, KeyCheck>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                Map<CloudAiProvider, KeyCheck>,
                Map<CloudAiProvider, KeyCheck>
              >,
              Map<CloudAiProvider, KeyCheck>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The saved key for [provider], masked for display, or null when none.

@ProviderFor(maskedAiKey)
final maskedAiKeyProvider = MaskedAiKeyFamily._();

/// The saved key for [provider], masked for display, or null when none.

final class MaskedAiKeyProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// The saved key for [provider], masked for display, or null when none.
  MaskedAiKeyProvider._({
    required MaskedAiKeyFamily super.from,
    required CloudAiProvider super.argument,
  }) : super(
         retry: null,
         name: r'maskedAiKeyProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$maskedAiKeyHash();

  @override
  String toString() {
    return r'maskedAiKeyProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    final argument = this.argument as CloudAiProvider;
    return maskedAiKey(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MaskedAiKeyProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$maskedAiKeyHash() => r'00ad788818d4ea7cc6081fea8e9f6f53e92f3cb3';

/// The saved key for [provider], masked for display, or null when none.

final class MaskedAiKeyFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String?>, CloudAiProvider> {
  MaskedAiKeyFamily._()
    : super(
        retry: null,
        name: r'maskedAiKeyProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The saved key for [provider], masked for display, or null when none.

  MaskedAiKeyProvider call(CloudAiProvider provider) =>
      MaskedAiKeyProvider._(argument: provider, from: this);

  @override
  String toString() => r'maskedAiKeyProvider';
}
