import 'package:genkit/genkit.dart';
import 'package:genkit_anthropic/genkit_anthropic.dart';

Future<void> run() => Genkit(plugins: [anthropic(apiKey: 'k')]).generate(model: anthropic.model('a'), prompt: 'hi');
