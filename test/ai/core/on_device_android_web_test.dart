import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_mlkit_genai/genkit_mlkit_genai.dart';
import 'package:nomorex/features/ai/core/ai_generate.dart';
import 'package:nomorex/features/ai/core/ai_key_store.dart';
import 'package:nomorex/features/ai/core/ai_provider_exception.dart';
import 'package:nomorex/features/ai/core/ai_task.dart';
import 'package:nomorex/features/ai/core/genkit_provider.dart';
import 'package:nomorex/features/ai/core/model_router_provider.dart';
import 'package:nomorex/features/ai/core/plugins/chrome_ai.dart';
import 'package:nomorex/features/ai/core/plugins/on_device_platforms.dart';
import 'package:schemantic/schemantic.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_fakes.dart';

MlKitModelStatus mlKitStatus(MlKitModelAvailability a, {int? done, int? total}) => MlKitModelStatus(
  availability: a,
  bytesDownloaded: done,
  bytesToDownload: total,
  sdkInt: 36,
  deviceModel: 'Pixel 10',
);

/// ML Kit answered in Dart. A download makes the model available.
class FakeMlKit implements MlKitGenAiApi {
  FakeMlKit(this.availability);

  MlKitModelAvailability availability;
  var downloads = 0;
  final prompts = <String>[];

  @override
  Future<MlKitModelStatus> status() async => mlKitStatus(availability);

  @override
  Future<void> startDownload() async {
    downloads++;
    availability = MlKitModelAvailability.downloading;
  }

  @override
  Future<MlKitGenerateResponse> generate(MlKitGenerateRequest request) async {
    prompts.add(request.prompt);
    return MlKitGenerateResponse(text: '{"title":"Leg Day"}', cutOff: false);
  }
}

/// Chrome's Prompt API answered in Dart.
class FakeChrome implements ChromeAiApi {
  FakeChrome(this.state, {this.downloadError, this.promptError});

  ChromeAiAvailability state;
  final ChromeAiException? downloadError;
  final ChromeAiException? promptError;
  final schemas = <Map<String, dynamic>?>[];
  final systems = <String?>[];
  Completer<void>? holdDownload;

  @override
  Future<ChromeAiAvailability> availability() async => state;

  @override
  Future<void> download(void Function(double progress) onProgress) async {
    if (downloadError case final e?) throw e;
    onProgress(0.25);
    await holdDownload?.future;
    onProgress(1);
    state = ChromeAiAvailability.available;
  }

  @override
  Future<ChromeAiReply> prompt({String? system, required String prompt, Map<String, dynamic>? schema}) async {
    if (promptError case final e?) throw e;
    systems.add(system);
    schemas.add(schema);
    return const ChromeAiReply('{"title":"Leg Day"}', inputTokens: 90);
  }
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
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('status mappings', () {
    test('ML Kit, with download progress from its bytes', () {
      expect(onDeviceStatusFromMlKit(mlKitStatus(MlKitModelAvailability.available)).modelName, kMlKitGenAiModel);
      expect(
        onDeviceStatusFromMlKit(mlKitStatus(MlKitModelAvailability.downloadable)).availability,
        OnDeviceAvailability.downloadable,
      );
      final downloading = onDeviceStatusFromMlKit(mlKitStatus(MlKitModelAvailability.downloading, done: 1, total: 4));
      expect(downloading.availability, OnDeviceAvailability.downloading);
      expect(downloading.downloadProgress, 0.25);
      expect(
        onDeviceStatusFromMlKit(mlKitStatus(MlKitModelAvailability.downloading)).downloadProgress,
        isNull,
        reason: 'started by another app: no bytes to show',
      );
      expect(onDeviceStatusFromMlKit(mlKitStatus(MlKitModelAvailability.unavailable)), OnDeviceStatus.unsupported);
    });

    test('Chrome', () {
      expect(onDeviceStatusFromChrome(ChromeAiAvailability.available).modelName, kChromeAiModel);
      expect(
        onDeviceStatusFromChrome(ChromeAiAvailability.downloadable).availability,
        OnDeviceAvailability.downloadable,
      );
      expect(onDeviceStatusFromChrome(ChromeAiAvailability.unavailable), OnDeviceStatus.unsupported);
    });

    test('platforms: ML Kit only in the Android app', () {
      expect(runsMlKitGenAi(platform: TargetPlatform.android, isWeb: false), isTrue);
      expect(runsMlKitGenAi(platform: TargetPlatform.android, isWeb: true), isFalse);
      expect(runsMlKitGenAi(platform: TargetPlatform.iOS, isWeb: false), isFalse);
    });
  });

  group('on Android', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);

    ProviderContainer containerFor(FakeMlKit mlKit) {
      final container = ProviderContainer(
        overrides: [
          aiKeyStoreProvider.overrideWithValue(FakeAiKeyStore()),
          mlKitGenAiProvider.overrideWithValue(mlKit),
        ],
      );
      addTearDown(container.dispose);
      container.listen(onDeviceAvailabilityProvider, (_, _) {});
      return container;
    }

    test('a ready model takes the small tasks, with the schema in its prompt', () async {
      final mlKit = FakeMlKit(MlKitModelAvailability.available);
      final container = containerFor(mlKit);
      await container.read(mlKitModelStatusProvider.future);

      final route = container.read(modelForTaskProvider(AiTask.suggestTitle))!;
      expect(route.modelName, kMlKitGenAiModel);
      expect(container.read(modelForTaskProvider(AiTask.import)), isNull);

      final ai = await container.read(genkitProvider.future);
      final reply = await generateWithRoute(ai, route, prompt: 'Name it', outputSchema: titleSchema);
      expect(reply.output, {'title': 'Leg Day'});
      expect(mlKit.prompts.single, contains('Answer with JSON data only'));
    });

    test('a downloadable model is offered, and the download shows as downloading at once', () async {
      final mlKit = FakeMlKit(MlKitModelAvailability.downloadable);
      final container = containerFor(mlKit);
      await container.read(mlKitModelStatusProvider.future);
      expect(container.read(onDeviceAvailabilityProvider)?.availability, OnDeviceAvailability.downloadable);
      expect(container.read(modelForTaskProvider(AiTask.suggestTitle)), isNull);

      await container.read(onDeviceDownloadProvider.notifier).start();
      expect(mlKit.downloads, 1);
      await container.read(mlKitModelStatusProvider.future);
      expect(container.read(onDeviceAvailabilityProvider)?.availability, OnDeviceAvailability.downloading);
    });
  });

  group('on the web', () {
    ProviderContainer containerFor(FakeChrome chrome) {
      final container = ProviderContainer(
        overrides: [
          aiKeyStoreProvider.overrideWithValue(FakeAiKeyStore()),
          // Tests don't run in a browser, so the web path is reached by
          // overriding the availability itself.
          chromeAiProvider.overrideWithValue(chrome),
          chromeAiAvailabilityProvider.overrideWith((ref) => ref.watch(chromeAiProvider).availability()),
          mlKitModelStatusProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);
      container.listen(onDeviceAvailabilityProvider, (_, _) {});
      return container;
    }

    test('a ready model takes the small tasks; the schema becomes responseConstraint', () async {
      final chrome = FakeChrome(ChromeAiAvailability.available);
      final container = containerFor(chrome);
      await container.read(chromeAiAvailabilityProvider.future);

      final route = container.read(modelForTaskProvider(AiTask.suggestTitle))!;
      expect(route.modelName, kChromeAiModel);
      final ai = await container.read(genkitProvider.future);
      final reply = await generateWithRoute(
        ai,
        route,
        system: 'You name workouts.',
        prompt: 'Name it',
        outputSchema: titleSchema,
      );
      expect(reply.output, {'title': 'Leg Day'});
      expect(chrome.systems.single, 'You name workouts.');
      expect(chrome.schemas.single, containsPair('required', ['title']));
    });

    test('the download reports its progress, then the model is ready', () async {
      final chrome = FakeChrome(ChromeAiAvailability.downloadable)..holdDownload = Completer();
      final container = containerFor(chrome);
      await container.read(chromeAiAvailabilityProvider.future);
      expect(container.read(onDeviceAvailabilityProvider)?.availability, OnDeviceAvailability.downloadable);

      final download = container.read(onDeviceDownloadProvider.notifier).start();
      await pumpEventQueue();
      final during = container.read(onDeviceAvailabilityProvider)!;
      expect(during.availability, OnDeviceAvailability.downloading);
      expect(during.downloadProgress, 0.25);

      chrome.holdDownload!.complete();
      await download;
      await container.read(chromeAiAvailabilityProvider.future);
      expect(container.read(onDeviceAvailabilityProvider)?.isReady, isTrue);
    });

    test('a failed download says so and can be tried again', () async {
      final chrome = FakeChrome(
        ChromeAiAvailability.downloadable,
        downloadError: const ChromeAiException('NotAllowedError', 'Requires a user gesture'),
      );
      final container = containerFor(chrome);
      await container.read(chromeAiAvailabilityProvider.future);
      await container.read(onDeviceDownloadProvider.notifier).start();
      final download = container.read(onDeviceDownloadProvider);
      expect(download.running, isFalse);
      expect(download.error, contains("didn't finish"));
    });

    test('a prompt too long for the context is the app\'s tooLong', () async {
      final chrome = FakeChrome(
        ChromeAiAvailability.available,
        promptError: const ChromeAiException('QuotaExceededError', 'The input is too large.'),
      );
      final container = containerFor(chrome);
      await container.read(chromeAiAvailabilityProvider.future);
      final route = container.read(modelForTaskProvider(AiTask.suggestTitle))!;
      final ai = await container.read(genkitProvider.future);
      await expectLater(
        generateWithRoute(ai, route, prompt: 'x', retryDelay: Duration.zero),
        throwsA(isA<AiProviderException>().having((e) => e.code, 'code', AiErrorCode.tooLong)),
      );
    });
  });

  test("a DOMException's name is read from its text", () {
    final e = chromeAiExceptionFrom('QuotaExceededError: The input is too large.');
    expect((e.name, e.message), ('QuotaExceededError', 'The input is too large.'));
    expect(chromeAiExceptionFrom('Error: NotAllowedError: Requires a user gesture').name, 'NotAllowedError');
    expect(chromeAiExceptionFrom('Something odd').name, 'Error');
    expect(genkitExceptionForChrome(const ChromeAiException('NotAllowedError', 'x')).status, StatusCode.unavailable);
  });
}
