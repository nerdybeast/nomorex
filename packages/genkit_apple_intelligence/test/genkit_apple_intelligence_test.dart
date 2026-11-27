import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_apple_intelligence/genkit_apple_intelligence.dart';
import 'package:schemantic/schemantic.dart';

/// Answers the bridge in Dart, recording each request.
class FakeApple implements AppleIntelligenceApi {
  FakeApple({this.reply = 'OK', this.errors = const []});

  String reply;

  /// Thrown by the first calls, in order.
  List<PlatformException> errors;
  final requests = <AppleGenerateRequest>[];

  @override
  Future<AppleModelStatus> status() async => ready;

  @override
  Future<AppleGenerateResponse> generate(AppleGenerateRequest request) async {
    requests.add(request);
    if (requests.length <= errors.length) throw errors[requests.length - 1];
    return AppleGenerateResponse(text: reply, inputTokens: 40, outputTokens: 5, schemaGaps: const []);
  }

  @override
  Future<int?> countTokens(String text) async => text.length ~/ 4;
}

final ready = AppleModelStatus(
  availability: AppleModelAvailability.available,
  contextSize: 8192,
  supportsImages: false,
  osVersion: '26.4.0',
);

final withImages = AppleModelStatus(
  availability: AppleModelAvailability.available,
  contextSize: 8192,
  supportsImages: true,
  osVersion: '27.2.1',
);

const _png =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGBgAAAABQABpfZFQAAAAABJRU5ErkJggg==';

Genkit genkitWith(FakeApple fake, {AppleModelStatus? status}) {
  final ai = Genkit(promptDir: null, isDevEnv: false);
  defineAppleIntelligenceModel(ai, status: status ?? ready, api: fake);
  return ai;
}

void main() {
  final model = modelRef(kAppleIntelligenceModel);

  test('sends system text as instructions, the rest as the prompt, always with a reply cap', () async {
    final fake = FakeApple(reply: 'Heavy Day');
    final ai = genkitWith(fake);
    final result = await ai.generate(model: model, system: 'Name workouts.', prompt: 'Squat 5x5');

    expect(result.text, 'Heavy Day');
    expect(result.usage?.inputTokens, 40);
    final request = fake.requests.single;
    expect(request.instructions, 'Name workouts.');
    expect(request.prompt, 'Squat 5x5');
    expect(request.schemaJson, isNull);
    expect(request.maximumResponseTokens, kAppleDefaultMaxResponseTokens);
  });

  test('passes the output cap and temperature from config', () async {
    final fake = FakeApple();
    await genkitWith(fake).generate(model: model, prompt: 'Hi', config: {'maxOutputTokens': 64, 'temperature': 0.2});
    expect(fake.requests.single.maximumResponseTokens, 64);
    expect(fake.requests.single.temperature, 0.2);
  });

  test('structured output sends the JSON schema for guided generation', () async {
    final fake = FakeApple(reply: '{"title":"Heavy Day"}');
    final result = await genkitWith(fake).generate(
      model: model,
      prompt: 'Name it',
      outputSchema: SchemanticType.from<Map<String, dynamic>>(
        jsonSchema: {
          'type': 'object',
          'properties': {
            'title': {'type': 'string'},
          },
          'required': ['title'],
        },
        parse: (json) => json as Map<String, dynamic>,
      ),
    );
    expect(result.output, {'title': 'Heavy Day'});
    expect(jsonDecode(fake.requests.single.schemaJson!), containsPair('type', 'object'));
  });

  test("a schema guided generation can't express goes in the prompt instead", () async {
    final fake = FakeApple(
      reply: '{"a":1}',
      errors: [PlatformException(code: 'schemaUnsupported', message: r'$: free-form map')],
    );
    await genkitWith(fake).generate(
      model: model,
      prompt: 'Give a map',
      outputSchema: SchemanticType.from<Map<String, dynamic>>(
        jsonSchema: {'type': 'object', 'additionalProperties': true},
        parse: (json) => json as Map<String, dynamic>,
      ),
    );
    expect(fake.requests, hasLength(2));
    expect(fake.requests.last.schemaJson, isNull);
    expect(fake.requests.last.prompt, contains('Answer with JSON data only'));
    expect(fake.requests.last.prompt, contains('additionalProperties'));
  });

  test('a refusal is a blocked result, not an error', () async {
    final fake = FakeApple(errors: [PlatformException(code: 'refused', message: 'guardrailViolation')]);
    final result = await genkitWith(fake).generate(model: model, prompt: 'x');
    expect(result.finishReason, FinishReason.blocked);
  });

  group('failures come back worded like the cloud providers', () {
    for (final (code, status, words) in [
      ('tooLong', StatusCode.invalidArgument, 'context window'),
      ('rateLimited', StatusCode.resourceExhausted, 'Rate limit'),
      ('unavailable', StatusCode.unavailable, 'unavailable'),
      ('failed', StatusCode.unknown, 'failed'),
    ]) {
      test(code, () {
        final e = genkitExceptionFor(PlatformException(code: code, message: 'detail'));
        expect(e.status, status);
        expect(e.message, contains(words));
      });
    }

    test('and Genkit reports them as a failed result', () async {
      final fake = FakeApple(errors: [PlatformException(code: 'tooLong', message: '8193 > 8192')]);
      final result = await genkitWith(fake).generate(model: model, prompt: 'x');
      expect(result.finishReason, FinishReason.failed);
    });
  });

  group('images', () {
    test('are refused before iOS / macOS 27', () async {
      final fake = FakeApple();
      final result = await genkitWith(fake).generate(
        model: model,
        promptParts: [
          TextPart(text: 'Read this'),
          MediaPart(media: Media(url: _png, contentType: 'image/png')),
        ],
      );
      expect(result.finishReason, FinishReason.failed);
      expect(fake.requests, isEmpty);
    });

    test('go through as bytes where the OS takes them, one per request', () async {
      final fake = FakeApple();
      await genkitWith(fake, status: withImages).generate(
        model: model,
        promptParts: [
          TextPart(text: 'Read this'),
          MediaPart(media: Media(url: _png, contentType: 'image/png')),
        ],
      );
      expect(fake.requests.single.image, isNotEmpty);
      expect(fake.requests.single.prompt, 'Read this');
    });
  });

  test('status on a platform without the plugin is unsupportedOS, never an error', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final status = await AppleIntelligence().status();
    expect(status.availability, AppleModelAvailability.unsupportedOS);
  });
}
