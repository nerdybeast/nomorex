// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The cloud provider choice (in `shared_preferences`) and which keys are
/// saved (in [AiKeyStore]). Device-local on purpose: a key belongs to this
/// device, not the account, and never reaches our server.

@ProviderFor(AiSettingsNotifier)
final aiSettingsProvider = AiSettingsNotifierProvider._();

/// The cloud provider choice (in `shared_preferences`) and which keys are
/// saved (in [AiKeyStore]). Device-local on purpose: a key belongs to this
/// device, not the account, and never reaches our server.
final class AiSettingsNotifierProvider
    extends $AsyncNotifierProvider<AiSettingsNotifier, AiSettings> {
  /// The cloud provider choice (in `shared_preferences`) and which keys are
  /// saved (in [AiKeyStore]). Device-local on purpose: a key belongs to this
  /// device, not the account, and never reaches our server.
  AiSettingsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiSettingsNotifierHash();

  @$internal
  @override
  AiSettingsNotifier create() => AiSettingsNotifier();
}

String _$aiSettingsNotifierHash() =>
    r'f50e95218d084d242a8c56352aba57adf3b7a3bf';

/// The cloud provider choice (in `shared_preferences`) and which keys are
/// saved (in [AiKeyStore]). Device-local on purpose: a key belongs to this
/// device, not the account, and never reaches our server.

abstract class _$AiSettingsNotifier extends $AsyncNotifier<AiSettings> {
  FutureOr<AiSettings> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<AiSettings>, AiSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AiSettings>, AiSettings>,
              AsyncValue<AiSettings>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
