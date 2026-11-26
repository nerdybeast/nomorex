import 'package:genkit/genkit.dart';
import 'package:nomorex/features/ai/core/ai_key_store.dart';
import 'package:nomorex/features/ai/core/ai_provider.dart';

/// Keys held in memory. [failing] makes every call fail the way a Linux
/// device with no keyring does.
class FakeAiKeyStore implements AiKeyStore {
  FakeAiKeyStore({Map<CloudAiProvider, String>? keys, this.failing = false}) : keys = {...?keys};

  final Map<CloudAiProvider, String> keys;
  final bool failing;

  void _check() {
    if (failing) throw KeyStorageUnavailableException(StateError('no keyring'));
  }

  @override
  Future<String?> read(CloudAiProvider provider) async {
    _check();
    return keys[provider];
  }

  @override
  Future<void> write(CloudAiProvider provider, String key) async {
    _check();
    keys[provider] = key;
  }

  @override
  Future<void> delete(CloudAiProvider provider) async {
    _check();
    keys.remove(provider);
  }
}

/// A Genkit with one fake model, `fake/model`, the same trick the Deno tests
/// use. [respond] answers each call; it can throw, or return a failed or
/// blocked response.
Genkit fakeGenkit(Future<ModelResponse> Function(ModelRequest request, int call) respond) {
  final ai = Genkit(promptDir: null, isDevEnv: false);
  var calls = 0;
  ai.defineModel(name: 'fake/model', fn: (req, ctx) => respond(req, ++calls));
  return ai;
}

ModelResponse textResponse(String text, {FinishReason finishReason = FinishReason.stop}) => ModelResponse(
  finishReason: finishReason,
  message: Message(role: Role.model, content: [TextPart(text: text)]),
);
