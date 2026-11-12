import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:nomorex/features/ai/models/ai_import_limits.dart';
import 'package:nomorex/features/ai/providers/ai_import_gate_provider.dart';
import 'package:nomorex/features/ai/providers/ai_import_intake_provider.dart';
import 'package:nomorex/features/ai/screens/ai_import_screen.dart';
import 'package:nomorex/features/ai/utils/import_file_check.dart';
import 'package:nomorex/features/ai/utils/import_file_picker.dart';
import 'package:nomorex/features/auth/providers/auth_provider.dart';

import 'ai_import_job_fakes.dart';

const _limits = AiImportLimits(maxImages: 8, maxPdfPages: 10, maxImageBytes: 7000000, maxPdfBytes: 20000000);

final _pngBytes = img.encodePng(img.Image(width: 4, height: 4));
ImportPage _image() => ImportPage(type: ImportFileType.png, bytes: _pngBytes);
ImportPage _pdf({String? name, int? pages}) =>
    ImportPage(type: ImportFileType.pdf, bytes: Uint8List.fromList('%PDF-1.7'.codeUnits), name: name, pdfPages: pages);

class _FakePicker implements ImportFilePicker {
  _FakePicker({this.canTakePhoto = false});

  @override
  final bool canTakePhoto;

  @override
  Future<XFile?> takePhoto() async => null;

  @override
  Future<List<XFile>> pickImages({required int limit}) async => const [];

  @override
  Future<List<XFile>> pickPdfs() async => const [];
}

class _StubIntake extends AiImportIntakeNotifier {
  _StubIntake(this.initial);

  final ImportIntakeState initial;
  int cancels = 0;
  int submits = 0;

  @override
  ImportIntakeState build() => initial;

  @override
  void cancel() => cancels++;

  @override
  Future<void> submit({String? requestedType}) async => submits++;
}

Future<_StubIntake> _pump(WidgetTester tester, ImportIntakeState initial, {bool canTakePhoto = false}) async {
  final intake = _StubIntake(initial);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentAuthUserProvider.overrideWithValue(null),
        aiImportLimitsProvider.overrideWith((ref) async => _limits),
        importFilePickerProvider.overrideWithValue(_FakePicker(canTakePhoto: canTakePhoto)),
        aiImportIntakeProvider.overrideWith(() => intake),
        aiImportGateProvider.overrideWith(() => FakeGate(const AiImportCheck(allowed: true))),
      ],
      child: const MaterialApp(home: AiImportScreen()),
    ),
  );
  // Not pumpAndSettle: an indeterminate progress bar never settles.
  await tester.pump();
  await tester.pump();
  return intake;
}

bool _enabled(WidgetTester tester, String key) => tester.widget<ButtonStyleButton>(find.byKey(Key(key))).enabled;

void main() {
  testWidgets('states the limits and offers images and PDFs', (tester) async {
    await _pump(tester, const ImportIntakeState());

    expect(find.textContaining('up to 8 images, or PDFs with up to 10 pages in total, each up to 20 MB'), findsOneWidget);
    expect(find.text('Choose PDFs'), findsOneWidget);
    expect(find.byKey(const Key('ai_import_take_photo')), findsNothing);
    expect(_enabled(tester, 'ai_import_choose_images'), isTrue);
    expect(_enabled(tester, 'ai_import_choose_pdf'), isTrue);
    expect(_enabled(tester, 'ai_import_upload'), isFalse, reason: 'nothing to upload yet');
  });

  testWidgets('offers the camera only where the picker can use one', (tester) async {
    await _pump(tester, const ImportIntakeState(), canTakePhoto: true);
    expect(find.byKey(const Key('ai_import_take_photo')), findsOneWidget);
  });

  testWidgets('lists chosen images with a working remove button each', (tester) async {
    await _pump(tester, ImportIntakeState(pages: [_image(), _image()]));

    expect(find.text('Page 1'), findsOneWidget);
    expect(find.text('Page 2'), findsOneWidget);
    expect(find.text('2/8'), findsOneWidget);
    expect(_enabled(tester, 'ai_import_choose_pdf'), isFalse, reason: 'never a PDF with images');
    expect(_enabled(tester, 'ai_import_upload'), isTrue);

    await tester.tap(find.byTooltip('Remove page 1'));
    await tester.pumpAndSettle();
    expect(find.text('Page 2'), findsNothing);
    expect(find.text('1/8'), findsOneWidget);
  });

  testWidgets('chosen PDFs block adding images, but more PDFs can be added', (tester) async {
    await _pump(
      tester,
      ImportIntakeState(pages: [_pdf(name: 'week 1.pdf', pages: 2), _pdf(name: 'week 2.pdf', pages: 1)]),
      canTakePhoto: true,
    );

    expect(find.text('PDFS'), findsOneWidget);
    expect(find.text('week 1.pdf'), findsOneWidget);
    expect(find.text('week 2.pdf'), findsOneWidget);
    expect(find.textContaining('2 pages'), findsOneWidget);
    expect(find.text('3/10 pages'), findsOneWidget);
    expect(_enabled(tester, 'ai_import_take_photo'), isFalse);
    expect(_enabled(tester, 'ai_import_choose_images'), isFalse);
    expect(_enabled(tester, 'ai_import_choose_pdf'), isTrue);
    expect(find.byTooltip('Remove week 1.pdf'), findsOneWidget);
  });

  testWidgets('a PDF with no name or page count is numbered, and counted as a file', (tester) async {
    await _pump(tester, ImportIntakeState(pages: [_pdf(name: 'a.pdf', pages: 1), _pdf()]));
    expect(find.text('PDF 2'), findsOneWidget);
    expect(find.text('2 files'), findsOneWidget);
  });

  testWidgets('as many PDFs as the page cap blocks adding more', (tester) async {
    await _pump(tester, ImportIntakeState(pages: List.generate(10, (i) => _pdf(name: '$i.pdf'))));
    expect(_enabled(tester, 'ai_import_choose_pdf'), isFalse);
  });

  testWidgets('a full set of images blocks adding more', (tester) async {
    await _pump(tester, ImportIntakeState(pages: List.generate(8, (_) => _image())));
    expect(_enabled(tester, 'ai_import_choose_images'), isFalse);
  });

  testWidgets('shows the last error', (tester) async {
    await _pump(tester, ImportIntakeState(pages: [_image()], error: 'PDFs can have up to 10 pages.'));
    expect(find.byKey(const Key('ai_import_error')), findsOneWidget);
    expect(find.text('PDFs can have up to 10 pages.'), findsOneWidget);
  });

  testWidgets('upload shows progress and can be cancelled', (tester) async {
    final intake = await _pump(
      tester,
      ImportIntakeState(pages: [_image(), _image(), _image()], phase: ImportIntakePhase.uploading, uploaded: 1),
    );

    expect(find.text('Uploading 2 of 3…'), findsOneWidget);
    expect(find.byKey(const Key('ai_import_upload')), findsNothing);
    expect(find.byTooltip('Remove page 1'), findsOneWidget);
    expect(tester.widget<IconButton>(find.byKey(const Key('ai_import_remove_0'))).onPressed, isNull);

    await tester.ensureVisible(find.byKey(const Key('ai_import_cancel')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('ai_import_cancel')));
    expect(intake.cancels, 1);
  });

  testWidgets('starting the import can no longer be cancelled', (tester) async {
    await _pump(tester, ImportIntakeState(pages: [_image()], phase: ImportIntakePhase.starting, uploaded: 1));
    expect(find.text('Starting the import…'), findsOneWidget);
    expect(find.byKey(const Key('ai_import_cancel')), findsNothing);
  });

  testWidgets('upload button submits', (tester) async {
    final intake = await _pump(tester, ImportIntakeState(pages: [_image()]));
    await tester.ensureVisible(find.byKey(const Key('ai_import_upload')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('ai_import_upload')));
    expect(intake.submits, 1);
  });

  testWidgets('confirms once the import has started', (tester) async {
    await _pump(tester, const ImportIntakeState(phase: ImportIntakePhase.started, jobId: 'job-1'));
    expect(find.byKey(const Key('ai_import_started')), findsOneWidget);
    expect(find.text('Import started'), findsOneWidget);
  });
}
