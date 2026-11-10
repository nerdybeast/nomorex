import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:nomorex/features/ai/models/ai_import_limits.dart';
import 'package:nomorex/features/ai/providers/ai_import_intake_provider.dart';
import 'package:nomorex/features/ai/utils/genkit_call.dart';
import 'package:nomorex/features/ai/utils/import_file_check.dart';
import 'package:nomorex/features/ai/utils/import_file_picker.dart';
import 'package:nomorex/features/auth/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _user = User(
  id: 'u1',
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  createdAt: '2026-01-15T00:00:00Z',
);

const _limits = AiImportLimits(maxImages: 3, maxPdfPages: 10, maxImageBytes: 7000000, maxPdfBytes: 1000);

final _uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

XFile _png(String name, {int width = 40}) => XFile.fromData(
  img.encodePng(img.Image(width: width, height: 30)),
  name: name,
  path: name,
);

XFile _pdf(String name, String body) =>
    XFile.fromData(Uint8List.fromList(latin1.encode('%PDF-1.7\n$body\n%%EOF')), name: name, path: name);

class _FakePicker implements ImportFilePicker {
  List<XFile> images = [];
  XFile? pdf;
  Object? error;

  @override
  bool get canTakePhoto => true;

  @override
  Future<XFile?> takePhoto() async {
    if (error != null) throw error!;
    return images.isEmpty ? null : images.first;
  }

  @override
  Future<List<XFile>> pickImages({required int limit}) async {
    if (error != null) throw error!;
    return images;
  }

  @override
  Future<XFile?> pickPdf() async => pdf;
}

/// Records every network call, and fails or blocks on demand.
class _FakeIntake extends AiImportIntakeNotifier {
  AiImportCheck check = const AiImportCheck(allowed: true);
  final List<String> calls = [];
  final List<(String, String)> uploads = [];
  final List<List<String>> removed = [];
  int? failUploadAt;
  Completer<void>? holdFirstUpload;
  Object? startError;
  String? startedImportId;

  @override
  String? currentUserId() => 'u1';

  @override
  Future<AiImportCheck> checkImport() async {
    calls.add('check');
    return check;
  }

  @override
  Future<void> uploadFile(String path, Uint8List bytes, String contentType) async {
    calls.add('upload');
    if (uploads.isEmpty && holdFirstUpload != null) await holdFirstUpload!.future;
    if (failUploadAt == uploads.length) throw const StorageException('network down');
    uploads.add((path, contentType));
  }

  @override
  Future<void> removeFiles(List<String> paths) async {
    calls.add('remove');
    removed.add(paths);
  }

  @override
  Future<String> startImport(String importId, {String? requestedType}) async {
    calls.add('start');
    startedImportId = importId;
    if (startError != null) throw startError!;
    return 'job-1';
  }
}

void main() {
  late _FakePicker picker;
  late _FakeIntake intake;
  late ProviderContainer container;

  setUp(() {
    picker = _FakePicker();
    intake = _FakeIntake();
    container = ProviderContainer(
      overrides: [
        currentAuthUserProvider.overrideWithValue(_user),
        aiImportLimitsProvider.overrideWith((ref) async => _limits),
        importFilePickerProvider.overrideWithValue(picker),
        aiImportIntakeProvider.overrideWith(() => intake),
      ],
    );
    container.listen(aiImportIntakeProvider, (_, _) {});
  });

  tearDown(() => container.dispose());

  ImportIntakeState state() => container.read(aiImportIntakeProvider);
  AiImportIntakeNotifier notifier() => container.read(aiImportIntakeProvider.notifier);

  group('choosing images', () {
    test('adds picked images in order', () async {
      picker.images = [_png('a.png', width: 10), _png('b.png', width: 20)];
      await notifier().chooseImages();

      expect(state().pages, hasLength(2));
      expect(state().pages.every((p) => p.type == ImportFileType.png), isTrue);
      expect(img.decodePng(state().pages[1].bytes)!.width, 20);
      expect(state().error, isNull);
      expect(state().phase, ImportIntakePhase.selecting);
    });

    test('keeps only as many images as the cap allows and says so', () async {
      await notifier().addImages([_png('a.png'), _png('b.png'), _png('c.png'), _png('d.png')]);
      expect(state().pages, hasLength(3));
      expect(state().error, contains('up to 3 images'));

      await notifier().chooseImages();
      expect(state().pages, hasLength(3));
      expect(state().error, 'An import can have up to 3 images.');
    });

    test('skips a file that isn\'t an image and names it', () async {
      await notifier().addImages([
        _png('a.png'),
        XFile.fromData(Uint8List.fromList(utf8.encode('not an image')), name: 'notes.txt', path: 'notes.txt'),
      ]);
      expect(state().pages, hasLength(1));
      expect(state().error, '"notes.txt" isn\'t a JPEG, PNG or WebP image.');
    });

    test('reports a picker failure without changing the selection', () async {
      picker.error = Exception('denied');
      await notifier().takePhoto();
      expect(state().error, "Couldn't open the camera.");
      expect(state().pages, isEmpty);
    });

    test('removing a page keeps the rest in order', () async {
      await notifier().addImages([_png('a.png', width: 10), _png('b.png', width: 20), _png('c.png', width: 30)]);
      notifier().removeAt(0);
      expect(state().pages.map((p) => img.decodePng(p.bytes)!.width), [20, 30]);
    });
  });

  group('choosing a PDF', () {
    test('accepts a PDF within the limits', () async {
      picker.pdf = _pdf('plan.pdf', '<< /Type /Pages /Count 4 >>');
      await notifier().choosePdf();
      expect(state().isPdf, isTrue);
      expect(state().error, isNull);
    });

    test('refuses a file over the size limit before reading it', () async {
      await notifier().setPdf(XFile.fromData(Uint8List(5000), name: 'big.pdf', path: 'big.pdf'));
      expect(state().pages, isEmpty);
      expect(state().error, allOf(startsWith('PDFs can be up to '), contains('"big.pdf" is ')));
    });

    test('refuses a file that isn\'t really a PDF', () async {
      await notifier().setPdf(_png('scan.pdf'));
      expect(state().error, '"scan.pdf" isn\'t a PDF.');
    });

    test('refuses a password-protected PDF', () async {
      await notifier().setPdf(_pdf('locked.pdf', 'trailer << /Encrypt 3 0 R >>'));
      expect(state().error, contains('password protected'));
      expect(state().pages, isEmpty);
    });

    test('refuses a PDF over the page limit, naming both numbers', () async {
      await notifier().setPdf(_pdf('long.pdf', '<< /Type /Pages /Count 14 >>'));
      expect(state().error, 'PDFs can have up to 10 pages, and "long.pdf" has 14.');
    });
  });

  group('one PDF or images, never both', () {
    test('images can\'t be added to a PDF', () async {
      await notifier().setPdf(_pdf('plan.pdf', ''));
      picker.images = [_png('a.png')];
      await notifier().chooseImages();
      expect(state().isPdf, isTrue);
      expect(state().error, 'An import is either one PDF or up to 3 images, not both. Remove the PDF to add images.');
    });

    test('a PDF can\'t be added to images', () async {
      await notifier().addImages([_png('a.png')]);
      picker.pdf = _pdf('plan.pdf', '');
      await notifier().choosePdf();
      expect(state().hasImages, isTrue);
      expect(state().error, contains('Remove the images to choose a PDF.'));
    });
  });

  group('submit', () {
    test('checks, uploads every page in order, then starts the import', () async {
      await notifier().addImages([_png('a.png'), _png('b.png')]);
      await notifier().submit();

      expect(intake.calls, ['check', 'upload', 'upload', 'start']);
      final importId = intake.startedImportId!;
      expect(importId, matches(_uuid));
      expect(intake.uploads, [('u1/$importId/page-1.png', 'image/png'), ('u1/$importId/page-2.png', 'image/png')]);
      expect(state().phase, ImportIntakePhase.started);
      expect(state().jobId, 'job-1');
      expect(state().pages, isEmpty);
    });

    test('uploads nothing when the check refuses, and says why', () async {
      intake.check = const AiImportCheck(allowed: false, reason: 'active_import');
      await notifier().addImages([_png('a.png')]);
      await notifier().submit();

      expect(intake.calls, ['check']);
      expect(state().error, 'An import is already running. Wait for it to finish, then try again.');
      expect(state().pages, hasLength(1), reason: 'the selection survives for a retry');
    });

    test('names the cap and when it resets', () async {
      intake.check = AiImportCheck(
        allowed: false,
        reason: 'daily_limit',
        dailyLimit: 5,
        resetsAt: DateTime.utc(2026, 11, 10),
      );
      await notifier().addImages([_png('a.png')]);
      await notifier().submit();
      expect(state().error, startsWith("You've used all 5 of today's imports. You can import again at "));
    });

    test('a failed upload deletes the pages already uploaded', () async {
      intake.failUploadAt = 1;
      await notifier().addImages([_png('a.png'), _png('b.png'), _png('c.png')]);
      await notifier().submit();

      expect(intake.calls, ['check', 'upload', 'upload', 'remove']);
      expect(intake.removed.single, [intake.uploads.single.$1]);
      expect(state().error, 'The upload failed. Check your connection and try again.');
      expect(state().phase, ImportIntakePhase.selecting);
      expect(state().pages, hasLength(3));
    });

    test('cancelling stops after the current file and deletes what was uploaded', () async {
      intake.holdFirstUpload = Completer<void>();
      await notifier().addImages([_png('a.png'), _png('b.png')]);
      final done = notifier().submit();
      await Future<void>.delayed(Duration.zero);
      expect(state().phase, ImportIntakePhase.uploading);
      expect(state().canCancel, isTrue);

      notifier().cancel();
      intake.holdFirstUpload!.complete();
      await done;

      expect(intake.calls, ['check', 'upload', 'remove']);
      expect(intake.removed.single, hasLength(1));
      expect(state().phase, ImportIntakePhase.selecting);
      expect(state().error, isNull);
    });

    test('a refused start deletes the uploads and explains', () async {
      intake.startError = const GenkitFlowException('RESOURCE_EXHAUSTED', 'monthly_limit');
      await notifier().addImages([_png('a.png')]);
      await notifier().submit();

      expect(intake.calls, ['check', 'upload', 'start', 'remove']);
      expect(state().error, "You've reached this month's import limit.");
    });

    test('a start with an unknown outcome leaves the uploads for the import to read', () async {
      intake.startError = const GenkitFlowException('NETWORK', "Couldn't reach the AI service.");
      await notifier().addImages([_png('a.png')]);
      await notifier().submit();

      expect(intake.calls, ['check', 'upload', 'start']);
      expect(state().error, "Couldn't reach the AI service.");
    });

    test('does nothing with no files', () async {
      await notifier().submit();
      expect(intake.calls, isEmpty);
    });
  });

  test('newImportId makes version 4 UUIDs', () {
    final ids = {for (var i = 0; i < 50; i++) newImportId()};
    expect(ids, hasLength(50));
    expect(ids.every(_uuid.hasMatch), isTrue);
  });
}
