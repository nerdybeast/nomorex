import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nomorex/core/theme/app_theme.dart';
import 'package:nomorex/features/ai/core/ai_provider.dart';
import 'package:nomorex/features/ai/core/ai_task.dart';
import 'package:nomorex/features/ai/core/model_router_provider.dart';
import 'package:nomorex/features/ai/models/ai_import_limits.dart';
import 'package:nomorex/features/ai/providers/ai_import_intake_provider.dart';
import 'package:nomorex/features/ai/providers/ai_import_path_provider.dart';
import 'package:nomorex/features/ai/screens/ai_import_screen.dart';
import 'package:nomorex/features/ai/utils/import_file_check.dart';
import 'package:nomorex/features/ai/utils/import_file_picker.dart';
import 'package:nomorex/features/auth/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nomorex/features/ai/providers/ai_import_gate_provider.dart';

import '../support/call_counter.dart';
import 'ai_import_job_fakes.dart';
import 'core/ai_fakes.dart';

const _limits = AiImportLimits(maxImages: 8, maxPdfPages: 10, maxImageBytes: 7000000, maxPdfBytes: 14000000);
const _gemini = AiRoute(provider: 'gemini', modelName: 'googleai/gemini-3.5-flash', cloud: CloudAiProvider.gemini);

ImportPage _jpeg() => ImportPage(type: ImportFileType.jpeg, bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF]));

class _NoPicker extends ImportFilePicker {
  @override
  bool get canTakePhoto => false;
}

class _StubIntake extends AiImportIntakeNotifier {
  _StubIntake(this.initial);

  final ImportIntakeState initial;
  final runs = CallCounter();
  final discards = CallCounter();

  @override
  ImportIntakeState build() => initial;

  @override
  Future<void> restoreUnfinished() async {}

  @override
  Future<void> runLocally({String? requestedType}) async => runs();

  @override
  Future<void> discardRun() async => discards();
}

/// The import screen on [path], under a router with the settings page, so
/// links to it can be followed.
Future<_StubIntake> _pump(
  WidgetTester tester, {
  required ImportPath path,
  ImportIntakeState state = const ImportIntakeState(),
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final intake = _StubIntake(state);
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, _) => TextButton(onPressed: () => context.push('/ai-import'), child: const Text('open')),
      ),
      GoRoute(path: '/ai-import', builder: (_, _) => const AiImportScreen()),
      GoRoute(path: '/profile/ai-assistant', builder: (_, _) => const Scaffold(body: Text('AI assistant settings'))),
      GoRoute(path: '/shell/training', builder: (_, _) => const Scaffold(body: Text('Training'))),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentAuthUserProvider.overrideWithValue(null),
        ...aiDeviceOverrides(),
        aiImportPathProvider.overrideWithValue(path),
        modelForTaskProvider(AiTask.import).overrideWithValue(path == ImportPath.local ? _gemini : null),
        aiImportIntakeLimitsProvider.overrideWith((ref) async => _limits),
        importFilePickerProvider.overrideWithValue(_NoPicker()),
        aiImportIntakeProvider.overrideWith(() => intake),
        aiImportGateProvider.overrideWith(() => FakeGate(const AiImportCheck(allowed: true))),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  // Not pumpAndSettle: progress indicators never settle.
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return intake;
}

void main() {
  group('no key yet', () {
    testWidgets('offers the AI assistant settings, and entering it by hand', (tester) async {
      await _pump(tester, path: ImportPath.needsKey);
      expect(find.text('Add an AI key to import'), findsOneWidget);
      expect(find.textContaining('Gemini, Claude or ChatGPT'), findsOneWidget);
      expect(find.byKey(const Key('ai_import_choose_images')), findsNothing);

      await tester.tap(find.byKey(const Key('ai_import_set_up_key')));
      await tester.pumpAndSettle();
      expect(find.text('AI assistant settings'), findsOneWidget);
    });

    testWidgets('"Enter it by hand" goes to Training', (tester) async {
      await _pump(tester, path: ImportPath.needsKey);
      await tester.tap(find.byKey(const Key('ai_import_by_hand')));
      await tester.pumpAndSettle();
      expect(find.text('Training'), findsOneWidget);
    });
  });

  group('with a key', () {
    testWidgets('names the provider and counts the files on the button', (tester) async {
      await _pump(tester, path: ImportPath.local, state: ImportIntakeState(pages: [_jpeg(), _jpeg()]));
      expect(find.textContaining('Read with Gemini, using your key.'), findsOneWidget);
      expect(find.text('Import 2 photos'), findsOneWidget);
      expect(find.byKey(const Key('ai_import_use_own_key')), findsNothing, reason: 'already using one');
    });

    testWidgets('the first import shows the notice; declining reads nothing', (tester) async {
      final intake = await _pump(tester, path: ImportPath.local, state: ImportIntakeState(pages: [_jpeg()]));
      await tester.tap(find.byKey(const Key('ai_import_upload')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ai_import_local_notice')), findsOneWidget);
      expect(find.text('Before your first import with Gemini'), findsOneWidget);
      expect(find.textContaining("straight from this device to Google's Gemini"), findsOneWidget);
      expect(find.textContaining("Gemini's free tier"), findsOneWidget);

      await tester.tap(find.byKey(const Key('ai_import_local_notice_decline')));
      await tester.pumpAndSettle();
      expect(intake.runs.count, 0);
      expect((await SharedPreferences.getInstance()).getBool('ai_import_notice_gemini'), isNull);
    });

    testWidgets('continuing records the notice and reads the files', (tester) async {
      final intake = await _pump(tester, path: ImportPath.local, state: ImportIntakeState(pages: [_jpeg()]));
      await tester.tap(find.byKey(const Key('ai_import_upload')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ai_import_local_notice_accept')));
      await tester.pumpAndSettle();

      expect(intake.runs.count, 1);
      expect((await SharedPreferences.getInstance()).getBool('ai_import_notice_gemini'), isTrue);
    });

    testWidgets('once accepted on this device, the notice is not shown again', (tester) async {
      final intake = await _pump(
        tester,
        path: ImportPath.local,
        state: ImportIntakeState(pages: [_jpeg()]),
        prefs: {'ai_import_notice_gemini': true},
      );
      await tester.tap(find.byKey(const Key('ai_import_upload')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ai_import_local_notice')), findsNothing);
      expect(intake.runs.count, 1);
    });

    testWidgets('shows the steps, the time and Cancel while it reads', (tester) async {
      await _pump(
        tester,
        path: ImportPath.local,
        state: ImportIntakeState(
          pages: [_jpeg(), _jpeg(), _jpeg()],
          phase: ImportIntakePhase.reading,
          provider: CloudAiProvider.gemini,
          readingSince: DateTime.now(),
        ),
      );
      expect(find.byKey(const Key('ai_import_local_progress')), findsOneWidget);
      expect(find.text('Gemini is reading 3 photos. This usually takes a minute or two.'), findsOneWidget);
      expect(find.text('Checked 3 photos'), findsOneWidget);
      expect(find.text('Reading with Gemini'), findsOneWidget);
      expect(find.byKey(const Key('ai_import_elapsed')), findsOneWidget);
      expect(tester.widget<ButtonStyleButton>(find.byKey(const Key('ai_import_cancel'))).enabled, isTrue);
    });

    testWidgets('a refused key offers the settings, trying again and discarding', (tester) async {
      final intake = await _pump(
        tester,
        path: ImportPath.local,
        state: ImportIntakeState(
          pages: [_jpeg()],
          phase: ImportIntakePhase.failed,
          provider: CloudAiProvider.gemini,
          failure: const ImportFailure(
            "Gemini didn't accept your key",
            'Check the key in AI assistant settings.',
            action: ImportFailureAction.checkKey,
          ),
        ),
      );
      expect(find.text("Gemini didn't accept your key"), findsOneWidget);
      expect(find.text('Check key'), findsOneWidget);
      expect(find.textContaining('uses your Gemini key again'), findsOneWidget);

      await tester.tap(find.byKey(const Key('ai_import_try_again')));
      await tester.pump();
      expect(intake.runs.count, 1);

      await tester.tap(find.byKey(const Key('ai_import_discard_run')));
      await tester.pump();
      expect(intake.discards.count, 1);

      await tester.tap(find.byKey(const Key('ai_import_open_settings')));
      await tester.pumpAndSettle();
      expect(find.text('AI assistant settings'), findsOneWidget);
    });

    testWidgets('files with nothing to read offer no retry', (tester) async {
      await _pump(
        tester,
        path: ImportPath.local,
        state: ImportIntakeState(
          pages: [_jpeg()],
          phase: ImportIntakePhase.failed,
          provider: CloudAiProvider.gemini,
          failure: const ImportFailure('No workout', 'None found.', action: ImportFailureAction.none),
        ),
      );
      expect(find.byKey(const Key('ai_import_try_again')), findsNothing);
      expect(find.byKey(const Key('ai_import_change_files')), findsOneWidget);
    });

    testWidgets('fits a phone without overflowing', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pump(
        tester,
        path: ImportPath.local,
        state: ImportIntakeState(
          pages: [_jpeg()],
          phase: ImportIntakePhase.reading,
          provider: CloudAiProvider.openai,
          readingSince: DateTime.now(),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the hosted alpha offers a way to use your own key instead', (tester) async {
    await _pump(tester, path: ImportPath.hosted);
    expect(find.text('Upload and import'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai_import_use_own_key')));
    await tester.pumpAndSettle();
    expect(find.text('AI assistant settings'), findsOneWidget);
  });
}
