import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_apple_intelligence/genkit_apple_intelligence.dart';
import 'package:nomorex/features/ai/core/ai_generate.dart';
import 'package:nomorex/features/ai/core/ai_key_store.dart';
import 'package:nomorex/features/ai/core/ai_provider.dart';
import 'package:nomorex/features/ai/core/ai_task.dart';
import 'package:nomorex/features/ai/core/genkit_provider.dart';
import 'package:nomorex/features/ai/core/model_router_provider.dart';
import 'package:nomorex/features/ai/core/plugins/apple_plugin.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_fakes.dart';

AppleModelStatus appleStatus(AppleModelAvailability availability) =>
    AppleModelStatus(availability: availability, contextSize: 8192, supportsImages: false, osVersion: '27.2.1');

/// Foundation Models answered in Dart.
class FakeApple implements AppleIntelligenceApi {
  FakeApple(this.availability);

  final AppleModelAvailability availability;
  final requests = <AppleGenerateRequest>[];

  @override
  Future<AppleModelStatus> status() async => appleStatus(availability);

  @override
  Future<AppleGenerateResponse> generate(AppleGenerateRequest request) async {
    requests.add(request);
    return AppleGenerateResponse(text: 'Heavy Squat Day', inputTokens: 60, outputTokens: 6, schemaGaps: const []);
  }

  @override
  Future<int?> countTokens(String text) async => null;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  ProviderContainer containerFor(FakeApple apple, {Map<CloudAiProvider, String>? keys}) {
    final container = ProviderContainer(
      overrides: [
        aiKeyStoreProvider.overrideWithValue(FakeAiKeyStore(keys: keys)),
        appleIntelligenceProvider.overrideWithValue(apple),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('asks Apple only on iOS and macOS apps', () {
    expect(runsAppleIntelligence(platform: TargetPlatform.iOS, isWeb: false), isTrue);
    expect(runsAppleIntelligence(platform: TargetPlatform.macOS, isWeb: false), isTrue);
    expect(runsAppleIntelligence(platform: TargetPlatform.macOS, isWeb: true), isFalse);
    expect(runsAppleIntelligence(platform: TargetPlatform.android, isWeb: false), isFalse);
  });

  test("Apple's availability, as the settings screen and router see it", () {
    OnDeviceAvailability of(AppleModelAvailability a) => onDeviceStatusFromApple(appleStatus(a)).availability;
    expect(of(AppleModelAvailability.available), OnDeviceAvailability.ready);
    expect(onDeviceStatusFromApple(appleStatus(AppleModelAvailability.available)).modelName, kAppleIntelligenceModel);
    expect(of(AppleModelAvailability.appleIntelligenceNotEnabled), OnDeviceAvailability.disabled);
    expect(of(AppleModelAvailability.modelNotReady), OnDeviceAvailability.downloading);
    for (final a in [
      AppleModelAvailability.deviceNotEligible,
      AppleModelAvailability.unsupportedOS,
      AppleModelAvailability.unavailable,
    ]) {
      expect(of(a), OnDeviceAvailability.unsupported, reason: a.name);
    }
  });

  group('on an Apple device', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);

    test('the small tasks route to Apple Intelligence, and imports still need a key', () async {
      final container = containerFor(FakeApple(AppleModelAvailability.available));
      await container.read(appleModelStatusProvider.future);

      expect(container.read(onDeviceAvailabilityProvider)?.isReady, isTrue);
      for (final task in [AiTask.suggestTitle, AiTask.suggestDescription, AiTask.suggestExercises]) {
        expect(container.read(modelForTaskProvider(task))?.modelName, kAppleIntelligenceModel);
      }
      expect(container.read(modelForTaskProvider(AiTask.import)), isNull, reason: 'imports are cloud only');
    });

    test('a test prompt runs through Genkit to the bridge', () async {
      final apple = FakeApple(AppleModelAvailability.available);
      final container = containerFor(apple);
      await container.read(appleModelStatusProvider.future);
      final route = container.read(modelForTaskProvider(AiTask.suggestTitle))!;
      final ai = await container.read(genkitProvider.future);

      final result = await generateWithRoute(ai, route, prompt: 'Name this workout', retryDelay: Duration.zero);
      expect(result.text, 'Heavy Squat Day');
      expect(apple.requests.single.prompt, 'Name this workout');
    });

    test('Apple Intelligence turned off: shown as off, and nothing routes on device', () async {
      final container = containerFor(FakeApple(AppleModelAvailability.appleIntelligenceNotEnabled));
      await container.read(appleModelStatusProvider.future);
      expect(container.read(onDeviceAvailabilityProvider)?.availability, OnDeviceAvailability.disabled);
      expect(container.read(modelForTaskProvider(AiTask.suggestTitle)), isNull);
      final ai = await container.read(genkitProvider.future);
      // Genkit reports an unknown model as a failed result, not a throw.
      final result = await ai
          .generate(model: modelRef(kAppleIntelligenceModel), prompt: 'x')
          .then((r) => r.finishReason, onError: (_) => FinishReason.failed);
      expect(result, FinishReason.failed, reason: 'the model is only defined when it can run');
    });

    test('a device that cannot run it reports unsupported', () async {
      final container = containerFor(FakeApple(AppleModelAvailability.deviceNotEligible));
      await container.read(appleModelStatusProvider.future);
      expect(container.read(onDeviceAvailabilityProvider), OnDeviceStatus.unsupported);
    });
  });
}
