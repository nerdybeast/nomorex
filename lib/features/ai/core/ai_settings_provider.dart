import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_key_store.dart';
import 'ai_provider.dart';

part 'ai_settings_provider.g.dart';

/// The lifter's AI choices on this device. Holds which keys are saved, never
/// the keys themselves, so nothing that logs this state can leak one.
@immutable
class AiSettings {
  const AiSettings({
    this.provider,
    this.savedKeys = const {},
    this.keyStorageAvailable = true,
    this.keyRevision = 0,
  });

  /// The cloud provider chosen for imports.
  final CloudAiProvider? provider;

  /// Providers with a key saved on this device.
  final Set<CloudAiProvider> savedKeys;

  /// False when the device can't store keys (Linux without a keyring).
  final bool keyStorageAvailable;

  /// Bumped on every key change, so anything built from a key (the plugins
  /// take it when they're created) rebuilds even when the set of saved
  /// providers stays the same.
  final int keyRevision;

  /// The chosen provider, if its key is saved: what can actually run.
  CloudAiProvider? get activeCloud => provider != null && savedKeys.contains(provider) ? provider : null;

  AiSettings copyWith({CloudAiProvider? provider, Set<CloudAiProvider>? savedKeys, int? keyRevision}) => AiSettings(
    provider: provider ?? this.provider,
    savedKeys: savedKeys ?? this.savedKeys,
    keyStorageAvailable: keyStorageAvailable,
    keyRevision: keyRevision ?? this.keyRevision,
  );

  @override
  bool operator ==(Object other) =>
      other is AiSettings &&
      other.provider == provider &&
      setEquals(other.savedKeys, savedKeys) &&
      other.keyStorageAvailable == keyStorageAvailable &&
      other.keyRevision == keyRevision;

  @override
  int get hashCode => Object.hash(provider, Object.hashAllUnordered(savedKeys), keyStorageAvailable, keyRevision);
}

/// The cloud provider choice (in `shared_preferences`) and which keys are
/// saved (in [AiKeyStore]). Device-local on purpose: a key belongs to this
/// device, not the account, and never reaches our server.
@Riverpod(keepAlive: true)
class AiSettingsNotifier extends _$AiSettingsNotifier {
  static const _providerKey = 'ai_cloud_provider';

  @override
  Future<AiSettings> build() async {
    CloudAiProvider? provider;
    try {
      final prefs = await SharedPreferences.getInstance();
      provider = CloudAiProvider.fromId(prefs.getString(_providerKey));
    } catch (_) {
      // No preferences storage: nothing chosen yet.
    }

    final store = ref.read(aiKeyStoreProvider);
    final saved = <CloudAiProvider>{};
    try {
      for (final p in CloudAiProvider.values) {
        final key = await store.read(p);
        if (key != null && key.isNotEmpty) saved.add(p);
      }
    } on KeyStorageUnavailableException {
      return AiSettings(provider: provider, keyStorageAvailable: false);
    }
    return AiSettings(provider: provider, savedKeys: saved);
  }

  /// Chooses the cloud provider for imports.
  Future<void> selectProvider(CloudAiProvider provider) async {
    final current = await future;
    state = AsyncData(current.copyWith(provider: provider));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_providerKey, provider.id);
    } catch (_) {
      // Not saved; the choice still applies for this session.
    }
  }

  /// Saves [key] for [provider], and chooses [provider] if nothing is chosen
  /// yet. Throws [KeyStorageUnavailableException] if the device can't store it.
  Future<void> saveKey(CloudAiProvider provider, String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(key, 'key', 'must not be empty');
    final current = await future;
    await ref.read(aiKeyStoreProvider).write(provider, trimmed);
    state = AsyncData(
      current.copyWith(savedKeys: {...current.savedKeys, provider}, keyRevision: current.keyRevision + 1),
    );
    if (current.provider == null) await selectProvider(provider);
  }

  /// Removes [provider]'s key from this device.
  Future<void> removeKey(CloudAiProvider provider) async {
    final current = await future;
    await ref.read(aiKeyStoreProvider).delete(provider);
    state = AsyncData(
      current.copyWith(
        savedKeys: {...current.savedKeys}..remove(provider),
        keyRevision: current.keyRevision + 1,
      ),
    );
  }
}
