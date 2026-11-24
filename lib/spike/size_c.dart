import 'package:genkit/genkit.dart';
import 'package:material_ui/material_ui.dart';

import 'size_c_anthropic.dart' deferred as a;
import 'size_c_gemini.dart' deferred as g;
import 'size_c_openai.dart' deferred as o;

void main() {
  runApp(MaterialApp(home: Column(children: [
    TextButton(onPressed: () async { await a.loadLibrary(); await a.run(); }, child: const Text('a')),
    TextButton(onPressed: () async { await o.loadLibrary(); await o.run(); }, child: const Text('o')),
    TextButton(onPressed: () async { await g.loadLibrary(); await g.run(); }, child: const Text('g')),
    TextButton(onPressed: () => Genkit().generate(model: modelRef('x/y'), prompt: 'hi'), child: const Text('core')),
  ])));
}
