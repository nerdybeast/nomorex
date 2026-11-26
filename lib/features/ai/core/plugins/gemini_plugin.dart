// Loaded with `deferred as` from cloud_plugins.dart.
import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';

// Sends the key in the x-goog-api-key header, not the URL (#183).
GenkitPlugin plugin(String apiKey) => googleAI(apiKey: apiKey);
