import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_mlkit_genai/genkit_mlkit_genai.dart';
import 'package:schemantic/schemantic.dart';

/// Answers the bridge in Dart, recording each request.
class FakeMlKit implements MlKitGenAiApi {
  FakeMlKit({this.reply = 'OK', this.cutOff = false, this.error});

  String reply;
  bool cutOff;
  PlatformException? error;
  final requests = <MlKitGenerateRequest>[];
  var downloads = 0;

  @override
  Future<MlKitModelStatus> status() async => ready;

  @override
  Future<void> startDownload() async => downloads++;

  @override
  Future<MlKitGenerateResponse> generate(MlKitGenerateRequest request) async {
    requests.add(request);
    if (error case final e?) throw e;
    return MlKitGenerateResponse(text: reply, cutOff: cutOff, inputTokens: 30);
  }
}

final ready = MlKitModelStatus(
  availability: MlKitModelAvailability.available,
  tokenLimit: 4000,
  sdkInt: 36,
  deviceModel: 'Pixel 10',
);

Genkit genkitWith(FakeMlKit fake) {
  final ai = Genkit(promptDir: null, isDevEnv: false);
  defineMlKitGenAiModel(ai, status: ready, api: fake);
  return ai;
}

final titleSchema = SchemanticType.from<Map<String, dynamic>>(
  jsonSchema: {
    'type': 'object',
    'properties': {
      'title': {'type': 'string'},
    },
    'required': ['title'],
  },
  parse: (json) => Map<String, dynamic>.from(json as Map),
);

void main() {
  final model = modelRef(kMlKitGenAiModel);

  test('puts the instructions first and always caps the reply', () async {
    final fake = FakeMlKit(reply: 'Heavy Day');
    final result = await genkitWith(fake).generate(model: model, system: 'Name workouts.', prompt: 'Squat 5x5');

    expect(result.text, 'Heavy Day');
    expect(fake.requests.single.prompt, 'Name workouts.\n\nSquat 5x5');
    expect(fake.requests.single.maxOutputTokens, kMlKitDefaultMaxOutputTokens);
  });

  test('passes the cap and temperature from config', () async {
    final fake = FakeMlKit();
    await genkitWith(fake).generate(model: model, prompt: 'Hi', config: {'maxOutputTokens': 64, 'temperature': 0.3});
    expect(fake.requests.single.maxOutputTokens, 64);
    expect(fake.requests.single.temperature, closeTo(0.3, 1e-9));
  });

  test('structured output: the schema goes in the prompt, and the JSON reply is parsed', () async {
    final fake = FakeMlKit(reply: '{"title":"Heavy Day"}');
    final result = await genkitWith(fake).generate(model: model, prompt: 'Name it', outputSchema: titleSchema);

    expect(result.output, {'title': 'Heavy Day'});
    expect(fake.requests.single.prompt, startsWith('Name it\n\nAnswer with JSON data only'));
    expect(fake.requests.single.prompt, contains('"required":["title"]'));
  });

  test('a reply that stops at the cap is cut off, not a success', () async {
    final result = await genkitWith(FakeMlKit(reply: '{"title":', cutOff: true)).generate(model: model, prompt: 'x');
    expect(result.finishReason, FinishReason.length);
  });

  test('images are refused: this model takes text only', () async {
    final fake = FakeMlKit();
    final result = await genkitWith(fake).generate(
      model: model,
      promptParts: [
        TextPart(text: 'Read this'),
        MediaPart(media: Media(url: 'data:image/png;base64,AAAA', contentType: 'image/png')),
      ],
    );
    expect(result.finishReason, FinishReason.failed);
    expect(fake.requests, isEmpty);
  });

  group('failures come back worded like the cloud providers', () {
    for (final (code, status, words) in [
      ('tooLong', StatusCode.invalidArgument, 'context window'),
      ('busy', StatusCode.resourceExhausted, 'Rate limit'),
      ('unavailable', StatusCode.unavailable, 'unavailable'),
      ('failed', StatusCode.unknown, 'failed'),
    ]) {
      test(code, () {
        final e = genkitExceptionForMlKit(PlatformException(code: code, message: 'detail'));
        expect(e.status, status);
        expect(e.message, contains(words));
      });
    }

    test('and Genkit reports them as a failed result', () async {
      final fake = FakeMlKit(error: PlatformException(code: 'busy', message: 'BUSY'));
      final result = await genkitWith(fake).generate(model: model, prompt: 'x');
      expect(result.finishReason, FinishReason.failed);
    });
  });

  test('status on a platform without the plugin is unavailable, never an error', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final status = await MlKitGenAi().status();
    expect(status.availability, MlKitModelAvailability.unavailable);
  });
}
