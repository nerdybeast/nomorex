import 'package:flutter/foundation.dart';
import 'package:genkit/genkit.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/ai_generate.dart';
import '../core/ai_key_store.dart';
import '../core/ai_provider.dart';
import '../core/ai_provider_exception.dart';
import '../core/ai_settings_provider.dart';
import '../core/ai_task.dart';
import '../core/plugins/cloud_plugins.dart';
import '../utils/ai_provider_info.dart';

part 'ai_key_check_provider.g.dart';

/// Checks a key with a tiny request on the provider's cheapest model. Listing
/// models would cost nothing, but Anthropic's plugin hides a refused key
/// there; a real request also catches an empty balance. Throws
/// [AiProviderException].
typedef AiKeyChecker = Future<void> Function(CloudAiProvider provider, String key);

Future<void> _checkKey(CloudAiProvider provider, String key) async {
  final ai = Genkit(plugins: [await loadCloudPlugin(provider, key)], promptDir: null, isDevEnv: false);
  try {
    await generateWithRoute(
      ai,
      cloudRoute(provider, ModelTier.fast),
      prompt: 'Reply with the single word OK.',
      timeout: const Duration(seconds: 30),
    );
  } finally {
    await ai.shutdown();
  }
}

/// Overridden in tests so nothing reaches a provider.
@Riverpod(keepAlive: true)
AiKeyChecker aiKeyChecker(Ref ref) => _checkKey;

/// The outcome of the last check on this screen.
@immutable
sealed class KeyCheck {
  const KeyCheck();
}

class KeyCheckRunning extends KeyCheck {
  const KeyCheckRunning();
}

class KeyCheckPassed extends KeyCheck {
  const KeyCheckPassed();
}

class KeyCheckFailed extends KeyCheck {
  const KeyCheckFailed(this.message);

  final String message;
}

/// Saves, tests and removes keys for the settings screen, and remembers the
/// last check per provider until the screen closes.
@riverpod
class AiKeyCheckNotifier extends _$AiKeyCheckNotifier {
  @override
  Map<CloudAiProvider, KeyCheck> build() => const {};

  void _set(CloudAiProvider provider, KeyCheck? check) {
    if (!ref.mounted) return;
    state = {...state}..remove(provider);
    if (check != null) state = {...state, provider: check};
  }

  /// Tests [key] first, and saves it unless the provider refused it: a key
  /// that fails only for a moment (offline, an outage, no credit yet) is
  /// still worth keeping.
  Future<void> saveAndTest(CloudAiProvider provider, String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      _set(provider, KeyCheckFailed('Paste your ${provider.label} API key first.'));
      return;
    }
    _set(provider, const KeyCheckRunning());
    KeyCheck result = const KeyCheckPassed();
    try {
      await ref.read(aiKeyCheckerProvider)(provider, trimmed);
    } on AiProviderException catch (e) {
      if (e.code == AiErrorCode.invalidKey) {
        _set(provider, KeyCheckFailed(_refused(provider)));
        return;
      }
      result = KeyCheckFailed('Saved, but the test failed. ${e.message}');
    }
    try {
      await ref.read(aiSettingsProvider.notifier).saveKey(provider, trimmed);
      await ref.read(aiSettingsProvider.notifier).selectProvider(provider);
    } on KeyStorageUnavailableException {
      result = const KeyCheckFailed("This device couldn't save the key.");
    }
    _set(provider, result);
  }

  /// Tests the saved key.
  Future<void> test(CloudAiProvider provider) async {
    _set(provider, const KeyCheckRunning());
    try {
      final key = await ref.read(aiKeyStoreProvider).read(provider);
      if (key == null) throw AiProviderException(AiErrorCode.invalidKey, provider: provider);
      await ref.read(aiKeyCheckerProvider)(provider, key);
      _set(provider, const KeyCheckPassed());
    } on AiProviderException catch (e) {
      _set(provider, KeyCheckFailed(e.code == AiErrorCode.invalidKey ? _refused(provider) : e.message));
    } on KeyStorageUnavailableException {
      _set(provider, const KeyCheckFailed("This device couldn't read the saved key."));
    }
  }

  // The general message points to these settings, which is where this is.
  static String _refused(CloudAiProvider provider) =>
      "${provider.label} didn't accept this key. Check that you copied all of it, or make a new one.";

  Future<void> remove(CloudAiProvider provider) async {
    await ref.read(aiSettingsProvider.notifier).removeKey(provider);
    _set(provider, null);
  }
}

/// The saved key for [provider], masked for display, or null when none.
@riverpod
Future<String?> maskedAiKey(Ref ref, CloudAiProvider provider) async {
  final settings = await ref.watch(aiSettingsProvider.future);
  if (!settings.savedKeys.contains(provider)) return null;
  try {
    final key = await ref.read(aiKeyStoreProvider).read(provider);
    return key == null ? null : maskKey(key);
  } on KeyStorageUnavailableException {
    return null;
  }
}
