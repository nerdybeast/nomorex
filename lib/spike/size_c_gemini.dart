import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';

Future<void> run() => Genkit(plugins: [googleAI(apiKey: 'k')]).generate(model: googleAI.gemini('g'), prompt: 'hi');
