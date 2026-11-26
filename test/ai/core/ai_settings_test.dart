import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/ai/core/ai_key_store.dart';
import 'package:nomorex/features/ai/core/ai_provider.dart';
import 'package:nomorex/features/ai/core/ai_settings_provider.dart';
import 'package:nomorex/features/ai/core/ai_task.dart';
import 'package:nomorex/features/ai/core/genkit_provider.dart';
import 'package:nomorex/features/ai/core/model_router_provider.dart';
import 'package:nomorex/features/ai/core/plugins/cloud_plugins.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_fakes.dart';

ProviderContainer containerWith(FakeAiKeyStore store) {
  final container = ProviderContainer(overrides: [aiKeyStoreProvider.overrideWithValue(store)]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('starts with nothing chosen and no keys', () async {
    final container = containerWith(FakeAiKeyStore());
    final settings = await container.read(aiSettingsProvider.future);
    expect(settings.provider, isNull);
    expect(settings.savedKeys, isEmpty);
    expect(settings.keyStorageAvailable, isTrue);
    expect(settings.activeCloud, isNull);
    expect(container.read(modelForTaskProvider(AiTask.import)), isNull);
  });

  test('saving the first key chooses its provider and routes imports to it', () async {
    final store = FakeAiKeyStore();
    final container = containerWith(store);
    await container.read(aiSettingsProvider.notifier).saveKey(CloudAiProvider.gemini, '  AIza-test  ');

    expect(store.keys[CloudAiProvider.gemini], 'AIza-test', reason: 'saved trimmed');
    final settings = container.read(aiSettingsProvider).value!;
    expect(settings.activeCloud, CloudAiProvider.gemini);
    expect(container.read(modelForTaskProvider(AiTask.import))!.cloud, CloudAiProvider.gemini);
    expect((await SharedPreferences.getInstance()).getString('ai_cloud_provider'), 'gemini');
  });

  test('keys are kept per provider, so switching back needs no new key', () async {
    final container = containerWith(FakeAiKeyStore());
    final notifier = container.read(aiSettingsProvider.notifier);
    await notifier.saveKey(CloudAiProvider.gemini, 'g');
    await notifier.saveKey(CloudAiProvider.anthropic, 'a');
    expect(container.read(aiSettingsProvider).value!.activeCloud, CloudAiProvider.gemini,
        reason: 'a second key does not change the choice');

    await notifier.selectProvider(CloudAiProvider.anthropic);
    expect(container.read(aiSettingsProvider).value!.activeCloud, CloudAiProvider.anthropic);
    await notifier.selectProvider(CloudAiProvider.gemini);
    expect(container.read(aiSettingsProvider).value!.activeCloud, CloudAiProvider.gemini);
  });

  test('choosing a provider without a key runs nothing', () async {
    final container = containerWith(FakeAiKeyStore());
    await container.read(aiSettingsProvider.notifier).selectProvider(CloudAiProvider.openai);
    expect(container.read(aiSettingsProvider).value!.activeCloud, isNull);
    expect(container.read(modelForTaskProvider(AiTask.import)), isNull);
  });

  test('removing the key stops routing to it', () async {
    final store = FakeAiKeyStore(keys: {CloudAiProvider.anthropic: 'a'});
    SharedPreferences.setMockInitialValues({'ai_cloud_provider': 'anthropic'});
    final container = containerWith(store);
    expect((await container.read(aiSettingsProvider.future)).activeCloud, CloudAiProvider.anthropic);

    await container.read(aiSettingsProvider.notifier).removeKey(CloudAiProvider.anthropic);
    expect(store.keys, isEmpty);
    expect(container.read(aiSettingsProvider).value!.activeCloud, isNull);
  });

  test('replacing a key rebuilds what was made from the old one', () async {
    final container = containerWith(FakeAiKeyStore());
    final notifier = container.read(aiSettingsProvider.notifier);
    await notifier.saveKey(CloudAiProvider.openai, 'old');
    final before = container.read(aiSettingsProvider).value!;
    await notifier.saveKey(CloudAiProvider.openai, 'new');
    expect(container.read(aiSettingsProvider).value, isNot(before));
  });

  test('a device that cannot store keys says so', () async {
    final container = containerWith(FakeAiKeyStore(failing: true));
    final settings = await container.read(aiSettingsProvider.future);
    expect(settings.keyStorageAvailable, isFalse);
    expect(settings.activeCloud, isNull);
    await expectLater(
      container.read(aiSettingsProvider.notifier).saveKey(CloudAiProvider.gemini, 'g'),
      throwsA(isA<KeyStorageUnavailableException>()),
    );
  });

  test('an empty key is refused', () async {
    final container = containerWith(FakeAiKeyStore());
    await expectLater(
      container.read(aiSettingsProvider.notifier).saveKey(CloudAiProvider.gemini, '   '),
      throwsArgumentError,
    );
  });

  test('genkitProvider builds with no plugin when no key is saved', () async {
    final container = containerWith(FakeAiKeyStore());
    final ai = await container.read(genkitProvider.future);
    expect(ai, isNotNull);
  });

  test('each provider plugin loads under the namespace the router uses', () async {
    for (final provider in CloudAiProvider.values) {
      final plugin = await loadCloudPlugin(provider, 'test-key');
      expect(plugin.name, kCloudNamespaces[provider]);
      expect(routeTask(AiTask.import, cloud: provider)!.modelName, startsWith('${plugin.name}/'));
    }
  });

  test('genkitProvider builds with the chosen provider plugin', () async {
    for (final provider in CloudAiProvider.values) {
      SharedPreferences.setMockInitialValues({'ai_cloud_provider': provider.id});
      final container = containerWith(FakeAiKeyStore(keys: {provider: 'test-key'}));
      expect(await container.read(genkitProvider.future), isNotNull);
    }
  });

  test('on device is unsupported until Stages 7 and 8', () {
    final container = containerWith(FakeAiKeyStore());
    expect(container.read(onDeviceAvailabilityProvider), OnDeviceStatus.unsupported);
    expect(container.read(modelForTaskProvider(AiTask.suggestTitle)), isNull);
  });
}
