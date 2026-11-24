import 'package:genkit/genkit.dart';
import 'package:genkit_openai/genkit_openai.dart';

Future<void> run() => Genkit(plugins: [openAI(apiKey: 'k')]).generate(model: openAI.model('o'), prompt: 'hi');
