import 'package:genkit/genkit.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'ai_key_store.dart';
import 'ai_settings_provider.dart';
import 'plugins/cloud_plugins.dart';

part 'genkit_provider.g.dart';

/// The app's Genkit instance, with the plugin for the chosen cloud provider
/// when its key is saved. On-device plugins join it in Stages 7 and 8.
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
  ref.onDispose(ai.shutdown);
  return ai;
}
