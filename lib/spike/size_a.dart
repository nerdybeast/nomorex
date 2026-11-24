import 'package:genkit/genkit.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final ai = Genkit();
  final m = ai.defineModel(name: 'x/y', fn: (r, c) async => ModelResponse(finishReason: FinishReason.stop));
  runApp(MaterialApp(home: TextButton(onPressed: () => ai.generate(model: modelRef(m.name), prompt: 'hi'), child: const Text('core'))));
}
