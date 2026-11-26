import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart';
import 'package:import_pipeline/import_pipeline.dart'
    show ImportRunNoWorkout, ImportRunOk, ImportRunOutcome, ImportType;
import 'package:nomorex/features/ai/core/ai_provider.dart';
import 'package:nomorex/features/ai/core/ai_provider_exception.dart';
import 'package:nomorex/features/ai/core/ai_settings_provider.dart';
import 'package:nomorex/features/ai/models/ai_import_limits.dart';
import 'package:nomorex/features/ai/providers/ai_import_intake_provider.dart';
import 'package:nomorex/features/ai/providers/ai_import_path_provider.dart';
import 'package:nomorex/features/ai/utils/import_file_cache.dart';
import 'package:nomorex/features/ai/utils/import_file_cache_memory.dart';
import 'package:nomorex/features/ai/utils/import_file_check.dart';
import 'package:nomorex/features/auth/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/ai_fakes.dart';

const _limits = AiImportLimits(maxImages: 8, maxPdfPages: 10, maxImageBytes: 7000000, maxPdfBytes: 20000000);

ImportPage _jpeg() => ImportPage(type: ImportFileType.jpeg, bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 1, 2]));

/// How [_LocalIntake] answers the model call and the save.
class _Script {
  ImportRunOutcome outcome = const ImportRunOk({'type': 'workout'}, ImportType.workout);
  Object? readError;
  Completer<void>? holdRead;
  Object? saveError;
}

class _LocalIntake extends AiImportIntakeNotifier {
  _LocalIntake(this.script);

  final _Script script;
  final reads = <({String modelName, int pages, String? requestedType})>[];
  final saves = <({String importId, String provider, String detectedType, String? requestedType})>[];
  final calls = <String>[];

  @override
  String? currentUserId() => 'u1';

  @override
  Future<ImportRunOutcome> readFiles({
    required String modelName,
    required CloudAiProvider provider,
    required List<ImportPage> pages,
    required CancellationToken cancel,
    String? requestedType,
  }) async {
    reads.add((modelName: modelName, pages: pages.length, requestedType: requestedType));
    if (script.holdRead case final hold?) {
      await Future.any([hold.future, cancel.whenCancelled]);
      if (cancel.isCancelled) throw GenkitException('aborted', status: StatusCode.cancelled);
    }
    if (script.readError case final error?) throw error;
    return script.outcome;
  }

  @override
  Future<String> saveResult({
    required String importId,
    required String detectedType,
    required Map<String, dynamic> result,
    required CloudAiProvider provider,
    String? requestedType,
    String? model,
    int? inputTokens,
    int? outputTokens,
  }) async {
    saves.add((importId: importId, provider: provider.id, detectedType: detectedType, requestedType: requestedType));
    if (script.saveError case final error?) throw error;
    return 'job-${saves.length}';
  }

  @override
  Future<void> keepScreenOn(bool on) async => calls.add(on ? 'awake' : 'asleep');

  @override
  Future<AiImportCheck> checkImport() async {
    calls.add('hosted check');
    return const AiImportCheck(allowed: false, reason: 'imports_disabled');
  }
}

void main() {
  late _Script script;
  late _LocalIntake intake;
  late MemoryImportFileCache cache;
  late ProviderContainer container;

  Future<void> setUpWith({Map<CloudAiProvider, String>? keys, bool hostedOn = false, bool failingStore = false}) async {
    SharedPreferences.setMockInitialValues({if (keys != null && keys.isNotEmpty) 'ai_cloud_provider': keys.keys.first.id});
    script = _Script();
    intake = _LocalIntake(script);
    cache = MemoryImportFileCache();
    container = ProviderContainer(
      overrides: [
        currentAuthUserProvider.overrideWithValue(null),
        aiImportLimitsProvider.overrideWith(
          (ref) async => AiImportLimits(
            maxImages: _limits.maxImages,
            maxPdfPages: _limits.maxPdfPages,
            maxImageBytes: _limits.maxImageBytes,
            maxPdfBytes: _limits.maxPdfBytes,
            enabled: hostedOn,
          ),
        ),
        ...aiDeviceOverrides(keys: FakeAiKeyStore(keys: keys, failing: failingStore), cache: cache),
        aiImportIntakeProvider.overrideWith(() => intake),
      ],
    );
    addTearDown(container.dispose);
    container.listen(aiImportIntakeProvider, (_, _) {});
    container.listen(aiImportPathProvider, (_, _) {});
    await container.read(aiSettingsProvider.future);
    await container.read(aiImportLimitsProvider.future);
  }

  ImportIntakeState state() => container.read(aiImportIntakeProvider);
  AiImportIntakeNotifier notifier() => container.read(aiImportIntakeProvider.notifier);

  /// Puts two chosen photos in the intake, as the pickers would.
  void choosePhotos() => intake.state = ImportIntakeState(pages: [_jpeg(), _jpeg()]);

  group('which path an import takes', () {
    test("the lifter's own key wins over the hosted alpha", () async {
      await setUpWith(keys: {CloudAiProvider.gemini: 'AIza-test'}, hostedOn: true);
      expect(container.read(aiImportPathProvider), ImportPath.local);
      expect(container.read(aiImportAvailableProvider), isTrue);
    });

    test('with no key, the hosted alpha while it is on', () async {
      await setUpWith(hostedOn: true);
      expect(container.read(aiImportPathProvider), ImportPath.hosted);
    });

    test('with no key and the alpha off, the settings', () async {
      await setUpWith();
      expect(container.read(aiImportPathProvider), ImportPath.needsKey);
      expect(container.read(aiImportAvailableProvider), isTrue, reason: 'adding a key is a way in');
    });

    test('hidden where no key can be stored and the alpha is off', () async {
      await setUpWith(failingStore: true);
      expect(container.read(aiImportPathProvider), ImportPath.unavailable);
      expect(container.read(aiImportAvailableProvider), isFalse);
    });

    test("a local run takes its provider's file limits", () async {
      await setUpWith(keys: {CloudAiProvider.gemini: 'AIza-test'});
      final limits = await container.read(aiImportIntakeLimitsProvider.future);
      expect(limits.maxPdfBytes, 14000000, reason: "Gemini's inline request limit");
      expect(limits.maxTotalBytes, 14000000);
    });

    test('submit goes to the hosted path when no key is set', () async {
      await setUpWith(hostedOn: true);
      choosePhotos();
      await notifier().submit();
      expect(intake.calls, contains('hosted check'));
      expect(intake.reads, isEmpty);
    });
  });

  group('a run with the lifter\'s key', () {
    test('reads the files, saves the result and keeps the files for a re-run', () async {
      await setUpWith(keys: {CloudAiProvider.gemini: 'AIza-test'});
      choosePhotos();
      await notifier().submit();

      expect(intake.reads.single.modelName, 'googleai/gemini-3.5-flash');
      expect(intake.reads.single.pages, 2);
      final save = intake.saves.single;
      expect(save.provider, 'gemini');
      expect(save.detectedType, 'workout');
      expect(state().phase, ImportIntakePhase.started);
      expect(state().jobId, 'job-1');
      expect(state().provider, CloudAiProvider.gemini);

      final cached = await cache.load(save.importId);
      expect(cached?.jobId, 'job-1', reason: 'kept until accepted or discarded');
      expect(await cache.unfinished(), isNull);
      expect(intake.calls, ['awake', 'asleep'], reason: 'the screen stays on only while it reads');
    });

    test('a refused key keeps the files and points to the settings; a retry reuses the import', () async {
      await setUpWith(keys: {CloudAiProvider.anthropic: 'sk-ant-test'});
      choosePhotos();
      script.readError = GenkitException('invalid x-api-key', status: StatusCode.unauthenticated);
      await notifier().runLocally();

      expect(state().phase, ImportIntakePhase.failed);
      expect(state().failure?.action, ImportFailureAction.checkKey);
      expect(state().failure?.title, "Claude didn't accept your key");
      expect(state().failure?.message, isNot(contains('x-api-key')), reason: "never the provider's error");
      expect(state().pages, hasLength(2));
      final firstImport = state().importId;
      expect((await cache.unfinished())?.importId, firstImport);

      script.readError = null;
      await notifier().runLocally();
      expect(state().phase, ImportIntakePhase.started);
      expect(intake.saves.single.importId, firstImport);
    });

    test('each kind of failure says what to do', () async {
      await setUpWith(keys: {CloudAiProvider.gemini: 'AIza-test'});
      final cases = {
        AiErrorCode.billing: ImportFailureAction.switchProvider,
        AiErrorCode.rateLimited: ImportFailureAction.tryAgain,
        AiErrorCode.network: ImportFailureAction.tryAgain,
        AiErrorCode.tooLong: ImportFailureAction.none,
      };
      for (final MapEntry(key: code, value: action) in cases.entries) {
        final failure = importFailureFor(AiProviderException(code, provider: CloudAiProvider.gemini), CloudAiProvider.gemini);
        expect(failure.action, action, reason: code.name);
        expect(failure.message, isNotEmpty);
      }
    });

    test('files with no training in them can only be discarded or changed', () async {
      await setUpWith(keys: {CloudAiProvider.gemini: 'AIza-test'});
      choosePhotos();
      script.outcome = const ImportRunNoWorkout();
      await notifier().runLocally();
      expect(state().failure?.action, ImportFailureAction.none);
      expect(intake.saves, isEmpty);
    });

    test('too many imports waiting for review is explained', () async {
      await setUpWith(keys: {CloudAiProvider.gemini: 'AIza-test'});
      choosePhotos();
      script.saveError = const PostgrestException(message: 'too_many_pending: review or discard an import first');
      await notifier().runLocally();
      expect(state().failure?.message, contains('20 imports waiting'));
    });

    test('cancelling goes back to the chosen files and keeps nothing', () async {
      await setUpWith(keys: {CloudAiProvider.gemini: 'AIza-test'});
      choosePhotos();
      script.holdRead = Completer();
      final run = notifier().runLocally();
      await pumpEventQueue();
      expect(state().phase, ImportIntakePhase.reading);
      expect(state().canCancel, isTrue);

      notifier().cancel();
      await run;
      expect(state().phase, ImportIntakePhase.selecting);
      expect(state().pages, hasLength(2));
      expect(state().error, isNull);
      expect(await cache.unfinished(), isNull);
      expect(intake.saves, isEmpty);
    });

    test('changing the files after a failure, then discarding, removes them from the device', () async {
      await setUpWith(keys: {CloudAiProvider.gemini: 'AIza-test'});
      choosePhotos();
      script.readError = GenkitException('down', status: StatusCode.unavailable);
      await notifier().runLocally();
      notifier().backToFiles();
      expect(state().phase, ImportIntakePhase.selecting);
      expect(state().importId, isNotNull, reason: 'the next try replaces the cached copy');

      script.readError = GenkitException('down', status: StatusCode.unavailable);
      await notifier().runLocally();
      await notifier().discardRun();
      expect(state().pages, isEmpty);
      expect(await cache.unfinished(), isNull);
    });
  });

  group('after the app closed mid-run', () {
    test('the run is offered again with its files', () async {
      await setUpWith(keys: {CloudAiProvider.gemini: 'AIza-test'});
      await cache.save(
        CachedImport(importId: '11111111-1111-4111-8111-111111111111', provider: 'gemini', pages: [_jpeg(), _jpeg(), _jpeg()]),
      );
      await notifier().restoreUnfinished();

      expect(state().phase, ImportIntakePhase.failed);
      expect(state().failure?.title, 'The import stopped');
      expect(state().failure?.message, contains('3 photos are still on this device'));
      expect(state().failure?.message, contains('Gemini was reading'));

      await notifier().runLocally();
      expect(intake.saves.single.importId, '11111111-1111-4111-8111-111111111111');
    });

    test('a saved import is not offered, and nothing replaces files already chosen', () async {
      await setUpWith(keys: {CloudAiProvider.gemini: 'AIza-test'});
      await cache.save(
        CachedImport(importId: '22222222-2222-4222-8222-222222222222', provider: 'gemini', pages: [_jpeg()], jobId: 'j'),
      );
      await notifier().restoreUnfinished();
      expect(state().phase, ImportIntakePhase.selecting);

      await cache.save(CachedImport(importId: '33333333-3333-4333-8333-333333333333', provider: 'gemini', pages: [_jpeg()]));
      choosePhotos();
      await notifier().restoreUnfinished();
      expect(state().phase, ImportIntakePhase.selecting);
      expect(state().pages, hasLength(2));
    });
  });

  group('re-running as the other type', () {
    test("reads this device's copy again as the type asked for", () async {
      await setUpWith(keys: {CloudAiProvider.gemini: 'AIza-test'});
      const importId = '44444444-4444-4444-8444-444444444444';
      await cache.save(CachedImport(importId: importId, provider: 'gemini', pages: [_jpeg()], jobId: 'job-0'));

      expect(await notifier().rerunFromCache(importId, 'program'), isTrue);
      await pumpEventQueue();
      expect(intake.reads.single.requestedType, 'program');
      expect(intake.saves.single, (importId: importId, provider: 'gemini', detectedType: 'workout', requestedType: 'program'));
    });

    test('is refused when the device no longer has the files', () async {
      await setUpWith(keys: {CloudAiProvider.gemini: 'AIza-test'});
      expect(await notifier().rerunFromCache('55555555-5555-4555-8555-555555555555', 'program'), isFalse);
      expect(intake.reads, isEmpty);
    });
  });
}
