// Loaded with `deferred as` from cloud_plugins.dart.
import 'package:genkit/genkit.dart';
import 'package:genkit_openai/genkit_openai.dart';

GenkitPlugin plugin(String apiKey) => openAI(apiKey: apiKey);
