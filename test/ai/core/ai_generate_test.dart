import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart';
import 'package:http/http.dart' as http;
import 'package:nomorex/features/ai/core/ai_generate.dart';
import 'package:nomorex/features/ai/core/ai_provider.dart';
import 'package:nomorex/features/ai/core/ai_provider_exception.dart';
import 'package:nomorex/features/ai/core/ai_task.dart';
import 'package:nomorex/features/ai/core/genkit_provider.dart';

import 'ai_fakes.dart';

const route = AiRoute(provider: 'anthropic', modelName: 'fake/model', cloud: CloudAiProvider.anthropic);

Future<GenerateResult<dynamic>> run(Genkit ai) =>
    generateWithRoute(ai, route, prompt: 'Name this workout', retryDelay: Duration.zero);

Matcher throwsAi(AiErrorCode code) =>
    throwsA(isA<AiProviderException>().having((e) => e.code, 'code', code).having((e) => e.provider, 'provider',
        CloudAiProvider.anthropic));

void main() {
  test('returns a successful result', () async {
    final ai = fakeGenkit((req, _) async => textResponse('Heavy day'));
    expect((await run(ai)).text, 'Heavy day');
  });

  test('a model failure comes out as an exception, not a failed result', () async {
    final ai = fakeGenkit((req, _) async => throw GenkitException('bad key', status: StatusCode.unauthenticated));
    await expectLater(run(ai), throwsAi(AiErrorCode.invalidKey));
  });

  test('a network failure is reported as one', () async {
    final ai = fakeGenkit((req, _) async => throw http.ClientException('Failed host lookup'));
    await expectLater(run(ai), throwsAi(AiErrorCode.network));
  });

  test('an outage is retried, and succeeds when the provider recovers', () async {
    var calls = 0;
    final ai = fakeGenkit((req, call) async {
      calls = call;
      if (call < 3) throw GenkitException('high demand', status: StatusCode.unavailable);
      return textResponse('Heavy day');
    });
    expect((await run(ai)).text, 'Heavy day');
    expect(calls, 3);
  });

  test('a rate limit is not retried', () async {
    var calls = 0;
    final ai = fakeGenkit((req, call) async {
      calls = call;
      throw GenkitException('Rate limit reached', status: StatusCode.resourceExhausted);
    });
    await expectLater(run(ai), throwsAi(AiErrorCode.rateLimited));
    expect(calls, 1);
  });

  test('a blocked answer is refused, and a cut-off one too long', () async {
    await expectLater(
      run(fakeGenkit((req, _) async => textResponse('', finishReason: FinishReason.blocked))),
      throwsAi(AiErrorCode.refused),
    );
    await expectLater(
      run(fakeGenkit((req, _) async => textResponse('{"weeks": [', finishReason: FinishReason.length))),
      throwsAi(AiErrorCode.tooLong),
    );
  });

  test('genkitProvider can be overridden with the fake model', () async {
    final container = ProviderContainer(
      overrides: [genkitProvider.overrideWith((ref) async => fakeGenkit((req, _) async => textResponse('ok')))],
    );
    addTearDown(container.dispose);
    final ai = await container.read(genkitProvider.future);
    expect((await run(ai)).text, 'ok');
  });
}
