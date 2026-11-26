import 'package:genkit/genkit.dart';

import '../ai_provider.dart';
import 'anthropic_plugin.dart' deferred as anthropic_plugin;
import 'gemini_plugin.dart' deferred as gemini_plugin;
import 'openai_plugin.dart' deferred as openai_plugin;

/// Loads [provider]'s Genkit plugin, set up with [apiKey].
Future<GenkitPlugin> loadCloudPlugin(CloudAiProvider provider, String apiKey) async {
  switch (provider) {
    case CloudAiProvider.anthropic:
      await anthropic_plugin.loadLibrary();
      return anthropic_plugin.plugin(apiKey);
    case CloudAiProvider.openai:
      await openai_plugin.loadLibrary();
      return openai_plugin.plugin(apiKey);
    case CloudAiProvider.gemini:
      await gemini_plugin.loadLibrary();
      return gemini_plugin.plugin(apiKey);
  }
}
