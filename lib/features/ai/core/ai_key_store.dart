import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'ai_provider.dart';

part 'ai_key_store.g.dart';

/// The device can't store keys: on Linux without an unlocked keyring, for
/// example. The settings say so instead of failing.
class KeyStorageUnavailableException implements Exception {
  KeyStorageUnavailableException(this.cause);

  final Object cause;

  @override
  String toString() => 'KeyStorageUnavailableException';
}

/// Where the lifter's API keys live: the platform keychain or keystore, and
/// on web the browser's storage. One entry per provider, so switching back
/// doesn't mean pasting a key again. Keys never leave the device.
abstract class AiKeyStore {
  Future<String?> read(CloudAiProvider provider);
  Future<void> write(CloudAiProvider provider, String key);
  Future<void> delete(CloudAiProvider provider);
}

class SecureAiKeyStore implements AiKeyStore {
  const SecureAiKeyStore();

  // macOS: the data-protection keychain needs the keychain-sharing
  // entitlement, without which every call fails with -34018 (#183).
  static const _storage = FlutterSecureStorage(mOptions: MacOsOptions(usesDataProtectionKeychain: false));

  static String _name(CloudAiProvider provider) => 'ai_key_${provider.id}';

  @override
  Future<String?> read(CloudAiProvider provider) => _guard(() => _storage.read(key: _name(provider)));

  @override
  Future<void> write(CloudAiProvider provider, String key) =>
      _guard(() => _storage.write(key: _name(provider), value: key));

  @override
  Future<void> delete(CloudAiProvider provider) => _guard(() => _storage.delete(key: _name(provider)));

  static Future<T> _guard<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      throw KeyStorageUnavailableException(e);
    }
  }
}

/// Overridden in tests with an in-memory store.
@Riverpod(keepAlive: true)
AiKeyStore aiKeyStore(Ref ref) => const SecureAiKeyStore();
