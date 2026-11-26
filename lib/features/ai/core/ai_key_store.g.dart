// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_key_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Overridden in tests with an in-memory store.

@ProviderFor(aiKeyStore)
final aiKeyStoreProvider = AiKeyStoreProvider._();

/// Overridden in tests with an in-memory store.

final class AiKeyStoreProvider
    extends $FunctionalProvider<AiKeyStore, AiKeyStore, AiKeyStore>
    with $Provider<AiKeyStore> {
  /// Overridden in tests with an in-memory store.
  AiKeyStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiKeyStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiKeyStoreHash();

  @$internal
  @override
  $ProviderElement<AiKeyStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AiKeyStore create(Ref ref) {
    return aiKeyStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiKeyStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AiKeyStore>(value),
    );
  }
}

String _$aiKeyStoreHash() => r'39e6b1dd7d17c61a3fa96c25200320eb7649ac72';
