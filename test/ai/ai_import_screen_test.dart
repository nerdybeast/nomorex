import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:nomorex/features/ai/models/ai_import_limits.dart';
import 'package:nomorex/features/ai/providers/ai_import_intake_provider.dart';
import 'package:nomorex/features/ai/screens/ai_import_screen.dart';
import 'package:nomorex/features/ai/utils/import_file_check.dart';
import 'package:nomorex/features/ai/utils/import_file_picker.dart';
import 'package:nomorex/features/auth/providers/auth_provider.dart';

const _limits = AiImportLimits(maxImages: 8, maxPdfPages: 10, maxImageBytes: 7000000, maxPdfBytes: 20000000);

final _pngBytes = img.encodePng(img.Image(width: 4, height: 4));
ImportPage _image() => ImportPage(type: ImportFileType.png, bytes: _pngBytes);
ImportPage _pdf() => ImportPage(type: ImportFileType.pdf, bytes: Uint8List.fromList('%PDF-1.7'.codeUnits));

class _FakePicker implements ImportFilePicker {
  _FakePicker({this.canTakePhoto = false});

  @override
  final bool canTakePhoto;

  @override
  Future<XFile?> takePhoto() async => null;

  @override
  Future<List<XFile>> pickImages({required int limit}) async => const [];

  @override
  Future<XFile?> pickPdf() async => null;
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
  testWidgets('states the limits and offers images and a PDF', (tester) async {
    await _pump(tester, const ImportIntakeState());

    expect(find.textContaining('up to 8 images, or one PDF of up to 10 pages and 20 MB'), findsOneWidget);
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

  testWidgets('a chosen PDF blocks adding images', (tester) async {
    await _pump(tester, ImportIntakeState(pages: [_pdf()]), canTakePhoto: true);

    expect(find.text('PDF'), findsWidgets);
    expect(_enabled(tester, 'ai_import_take_photo'), isFalse);
    expect(_enabled(tester, 'ai_import_choose_images'), isFalse);
    expect(_enabled(tester, 'ai_import_choose_pdf'), isFalse);
    expect(find.byTooltip('Remove PDF'), findsOneWidget);
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
