import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nomorex/core/theme/app_theme.dart';
import 'package:nomorex/core/utils/external_link.dart';
import 'package:nomorex/features/ai/core/ai_key_store.dart';
import 'package:nomorex/features/ai/core/ai_provider.dart';
import 'package:nomorex/features/ai/core/ai_provider_exception.dart';
import 'package:nomorex/features/ai/core/ai_task.dart';
import 'package:nomorex/features/ai/core/model_router_provider.dart';
import 'package:nomorex/features/ai/providers/ai_key_check_provider.dart';
import 'package:nomorex/features/ai/screens/ai_assistant_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/call_counter.dart';
import 'core/ai_fakes.dart';

const phone = Size(390, 1600);
const desktop = Size(1280, 1600);

class Harness {
  Harness({Map<CloudAiProvider, String>? keys, bool failingStore = false, this.checkError, this.download})
    : store = FakeAiKeyStore(keys: keys, failing: failingStore);

  /// Replaces the on-device download, so nothing reaches a platform.
  final FakeDownload? download;

  final FakeAiKeyStore store;
  AiProviderException? checkError;
  final checked = <(CloudAiProvider, String)>[];
  final opened = <Uri>[];

  Future<void> pump(
    WidgetTester tester, {
    Size size = phone,
    OnDeviceStatus? onDevice,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiKeyStoreProvider.overrideWithValue(store),
          onDeviceAvailabilityProvider.overrideWithValue(onDevice),
          if (download case final download?) onDeviceDownloadProvider.overrideWith(() => download),
          aiKeyCheckerProvider.overrideWithValue((provider, key) async {
            checked.add((provider, key));
            if (checkError != null) throw checkError!;
          }),
          externalLinkOpenerProvider.overrideWithValue((uri) async {
            opened.add(uri);
            return true;
          }),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const AiAssistantScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }
}

Future<void> choose(WidgetTester tester, CloudAiProvider provider) async {
  await tester.tap(find.byKey(Key('ai_provider_${provider.id}')));
  await tester.pumpAndSettle();
}

Future<void> enterKeyAndSave(WidgetTester tester, String key) async {
  await tester.enterText(find.byKey(const Key('ai_key_field')), key);
  await tester.tap(find.byKey(const Key('ai_save_key')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final (name, size) in [('phone', phone), ('desktop', desktop)]) {
    group('on a $name', () {
      testWidgets('lists the providers with no key panel until one is chosen', (tester) async {
        await Harness().pump(tester, size: size);
        for (final p in CloudAiProvider.values) {
          expect(find.text(p.label), findsOneWidget);
        }
        expect(find.byKey(const Key('ai_key_field')), findsNothing);
        expect(find.text('Imports with your own key'), findsOneWidget);
      });

      testWidgets('a key is saved, tested, and the provider chosen', (tester) async {
        final h = Harness();
        await h.pump(tester, size: size);
        await choose(tester, CloudAiProvider.anthropic);
        expect(find.text('Claude API key'), findsOneWidget);
        expect(find.text('Imports with Claude'), findsOneWidget);

        await enterKeyAndSave(tester, 'sk-ant-api03-abcdefghijklmnop');
        expect(h.checked.single, (CloudAiProvider.anthropic, 'sk-ant-api03-abcdefghijklmnop'));
        expect(h.store.keys[CloudAiProvider.anthropic], 'sk-ant-api03-abcdefghijklmnop');
        expect(find.text('Key works'), findsOneWidget);
        expect(find.text('Key saved'), findsOneWidget);
        expect(find.text('sk-ant••••••••••••mnop'), findsOneWidget, reason: 'masked, never shown whole');
        expect(find.byKey(const Key('ai_test_key')), findsOneWidget);
        expect((await SharedPreferences.getInstance()).getString('ai_cloud_provider'), 'anthropic');
      });
    });
  }

  testWidgets('a refused key is not saved', (tester) async {
    final h = Harness(checkError: AiProviderException(AiErrorCode.invalidKey, provider: CloudAiProvider.openai));
    await h.pump(tester);
    await choose(tester, CloudAiProvider.openai);
    await enterKeyAndSave(tester, 'sk-wrong');
    expect(h.store.keys, isEmpty);
    expect(find.textContaining("ChatGPT didn't accept this key"), findsOneWidget);
    expect(find.byKey(const Key('ai_key_field')), findsOneWidget);
  });

  testWidgets('a key that fails only for now is saved, with the reason', (tester) async {
    final h = Harness(checkError: AiProviderException(AiErrorCode.network, provider: CloudAiProvider.gemini));
    await h.pump(tester);
    await choose(tester, CloudAiProvider.gemini);
    await enterKeyAndSave(tester, 'AIzaSyAbcdefghijklmnop');
    expect(h.store.keys[CloudAiProvider.gemini], 'AIzaSyAbcdefghijklmnop');
    expect(find.textContaining('Saved, but the test failed.'), findsOneWidget);
    expect(find.textContaining("Couldn't reach Gemini"), findsOneWidget);
  });

  testWidgets('an empty key asks for one and calls nothing', (tester) async {
    final h = Harness();
    await h.pump(tester);
    await choose(tester, CloudAiProvider.gemini);
    await tester.tap(find.byKey(const Key('ai_save_key')));
    await tester.pumpAndSettle();
    expect(h.checked, isEmpty);
    expect(find.text('Paste your Gemini API key first.'), findsOneWidget);
  });

  testWidgets('testing a saved key, and switching keeps each key', (tester) async {
    SharedPreferences.setMockInitialValues({'ai_cloud_provider': 'gemini'});
    final h = Harness(keys: {CloudAiProvider.gemini: 'AIzaSyGeminiKey0001', CloudAiProvider.anthropic: 'sk-ant-claudekey0001'});
    await h.pump(tester);
    expect(find.text('Key saved'), findsNWidgets(2));

    await tester.tap(find.byKey(const Key('ai_test_key')));
    await tester.pumpAndSettle();
    expect(h.checked.single, (CloudAiProvider.gemini, 'AIzaSyGeminiKey0001'));
    expect(find.text('Key works'), findsOneWidget);

    await choose(tester, CloudAiProvider.anthropic);
    expect(find.text('sk-ant••••••••••••0001'), findsOneWidget);
    expect(find.text('Key works'), findsNothing, reason: 'each provider has its own check');
    expect(h.store.keys.length, 2);
  });

  testWidgets('removing a key asks first, then deletes it', (tester) async {
    SharedPreferences.setMockInitialValues({'ai_cloud_provider': 'openai'});
    final h = Harness(keys: {CloudAiProvider.openai: 'sk-proj-openaikey0001'});
    await h.pump(tester);
    await tester.ensureVisible(find.byKey(const Key('ai_remove_key')));
    await tester.tap(find.byKey(const Key('ai_remove_key')));
    await tester.pumpAndSettle();
    expect(find.text('Remove ChatGPT key?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Remove key').last);
    await tester.pumpAndSettle();
    expect(h.store.keys, isEmpty);
    expect(find.byKey(const Key('ai_key_field')), findsOneWidget);
    expect(find.text('Key saved'), findsNothing);
  });

  testWidgets('the get-a-key link opens the provider page', (tester) async {
    final h = Harness();
    await h.pump(tester);
    await choose(tester, CloudAiProvider.anthropic);
    await tester.tap(find.byKey(const Key('ai_get_key')));
    await tester.pumpAndSettle();
    expect(h.opened.single.host, 'console.anthropic.com');
  });

  testWidgets('the free-tier note shows for Gemini only', (tester) async {
    await Harness().pump(tester);
    await choose(tester, CloudAiProvider.gemini);
    expect(find.byKey(const Key('ai_gemini_note')), findsOneWidget);
    await choose(tester, CloudAiProvider.anthropic);
    expect(find.byKey(const Key('ai_gemini_note')), findsNothing);
  });

  testWidgets('a device that cannot store keys says so instead of offering a field', (tester) async {
    await Harness(failingStore: true).pump(tester);
    expect(find.byKey(const Key('ai_key_storage_unavailable')), findsOneWidget);
    expect(find.byKey(const Key('ai_provider_gemini')), findsNothing);
  });

  group('on-device status', () {
    // Tests run as Android, whose model is Gemini Nano.
    testWidgets('ready', (tester) async {
      await Harness().pump(
        tester,
        onDevice: const OnDeviceStatus(OnDeviceAvailability.ready, modelName: 'mlkit/nano'),
      );
      expect(find.text('Gemini Nano'), findsOneWidget);
      expect(find.text('Ready'), findsOneWidget);
    });

    testWidgets('downloading shows progress', (tester) async {
      await Harness().pump(
        tester,
        onDevice: const OnDeviceStatus(OnDeviceAvailability.downloading, downloadProgress: 0.62),
      );
      expect(find.textContaining('downloading its on-device model'), findsOneWidget);
      expect(tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, 0.62);
    });

    testWidgets('downloadable offers the download, which the lifter starts', (tester) async {
      final download = FakeDownload();
      await Harness(download: download).pump(tester, onDevice: const OnDeviceStatus(OnDeviceAvailability.downloadable));
      expect(find.textContaining('large one-time download'), findsOneWidget);
      await tester.tap(find.byKey(const Key('ai_on_device_download')));
      await tester.pump();
      expect(download.starts.count, 1);
    });

    testWidgets('turned off', (tester) async {
      await Harness().pump(tester, onDevice: const OnDeviceStatus(OnDeviceAvailability.disabled));
      expect(find.text('Gemini Nano is off'), findsOneWidget);
    });

    testWidgets('not available', (tester) async {
      await Harness().pump(tester, onDevice: OnDeviceStatus.unsupported);
      expect(find.text('No on-device model here'), findsOneWidget);
      expect(find.text('Suggestions on this device'), findsOneWidget);
    });

    testWidgets('hidden while this build cannot ask the device', (tester) async {
      await Harness().pump(tester);
      expect(find.byKey(const Key('ai_on_device_status')), findsNothing);
      expect(find.text('No on-device model here'), findsNothing);
      expect(find.text('Suggestions on this device'), findsNothing);
      expect(find.byKey(const Key('ai_provider_gemini')), findsOneWidget);
    });

    testWidgets('names each platform model', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await Harness().pump(tester, onDevice: const OnDeviceStatus(OnDeviceAvailability.disabled));
      expect(find.text('Apple Intelligence is off'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}

class FakeDownload extends OnDeviceDownloadNotifier {
  final starts = CallCounter();

  @override
  OnDeviceDownload build() => const OnDeviceDownload();

  @override
  Future<void> start() async => starts();
}
