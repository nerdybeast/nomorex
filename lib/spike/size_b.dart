import 'package:genkit/genkit.dart';
import 'package:genkit_anthropic/genkit_anthropic.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:genkit_openai/genkit_openai.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final ai = Genkit(plugins: [anthropic(apiKey: 'k'), openAI(apiKey: 'k'), googleAI(apiKey: 'k')]);
  runApp(MaterialApp(home: Column(children: [
    TextButton(onPressed: () => ai.generate(model: anthropic.model('a'), prompt: 'hi'), child: const Text('a')),
    TextButton(onPressed: () => ai.generate(model: openAI.model('o'), prompt: 'hi'), child: const Text('o')),
    TextButton(onPressed: () => ai.generate(model: googleAI.gemini('g'), prompt: 'hi'), child: const Text('g')),
  ])));
}
