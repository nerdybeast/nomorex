import 'package:genkit/genkit.dart';
import 'package:genkit_apple_intelligence/genkit_apple_intelligence.dart';
import 'package:genkit_mlkit_genai/genkit_mlkit_genai.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'ai_key_store.dart';
import 'ai_settings_provider.dart';
import 'model_router_provider.dart';
import 'plugins/chrome_ai.dart';
import 'plugins/cloud_plugins.dart';

part 'genkit_provider.g.dart';

/// The app's Genkit instance, with the plugin for the chosen cloud provider
/// when its key is saved, and the on-device model where it's ready: Apple
/// Intelligence on iOS and macOS, Gemini Nano on Android, Chrome's built-in AI
/// on the web.
///
/// Rebuilt whenever the provider or a key changes, because plugins take the
/// key when they're created. Widget tests override this with a Genkit that
/// holds a fake model (`ai.defineModel`).
@Riverpod(keepAlive: true)
Future<Genkit> genkit(Ref ref) async {
  final settings = await ref.watch(aiSettingsProvider.future);
  final plugins = <GenkitPlugin>[];

  final cloud = settings.activeCloud;
  if (cloud != null) {
    String? key;
    try {
      key = await ref.read(aiKeyStoreProvider).read(cloud);
    } on KeyStorageUnavailableException {
      // Settings already report this; build without the plugin.
    }
    if (key != null && key.isNotEmpty) plugins.add(await loadCloudPlugin(cloud, key));
  }

  // No prompt folder and never the dev reflection server: this runs on
  // lifters' devices.
  final ai = Genkit(plugins: plugins, promptDir: null, isDevEnv: false);
  final apple = await ref.watch(appleModelStatusProvider.future);
  if (apple?.availability == AppleModelAvailability.available) {
    defineAppleIntelligenceModel(ai, status: apple!, api: ref.read(appleIntelligenceProvider));
  }
  final mlKit = await ref.watch(mlKitModelStatusProvider.future);
  if (mlKit?.availability == MlKitModelAvailability.available) {
    defineMlKitGenAiModel(ai, status: mlKit!, api: ref.read(mlKitGenAiProvider));
  }
  if (await ref.watch(chromeAiAvailabilityProvider.future) == ChromeAiAvailability.available) {
    defineChromeAiModel(ai, api: ref.read(chromeAiProvider));
  }
  ref.onDispose(ai.shutdown);
  return ai;
}
