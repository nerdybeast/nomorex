import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/ai_import_limits.dart';
import '../utils/genkit_call.dart';
import '../utils/import_file_check.dart';
import '../utils/import_file_picker.dart';
import '../utils/import_image_prep.dart';
import '../utils/import_messages.dart';
import 'ai_import_jobs_provider.dart';

part 'ai_import_intake_provider.g.dart';

/// The private bucket import files go to, at `{user_id}/{import_id}/{file}`.
const kAiImportBucket = 'ai-imports';

@riverpod
ImportFilePicker importFilePicker(Ref ref) => ImportFilePicker();

/// The file caps, read so files can be refused before upload. Not user data,
/// but re-read on sign-in anyway, since the row is only visible to
/// authenticated users.
@Riverpod(keepAlive: true)
Future<AiImportLimits> aiImportLimits(Ref ref) async {
  ref.watch(currentAuthUserProvider);
  final row = await Supabase.instance.client
      .from('ai_import_limits')
      .select('max_images, max_pdf_pages, max_image_bytes, max_pdf_bytes, max_job_seconds')
      .single();
  return AiImportLimits.fromJson(row);
}

/// One file in an import, ready to upload.
class ImportPage {
  const ImportPage({required this.type, required this.bytes});

  final ImportFileType type;
  final Uint8List bytes;
}

enum ImportIntakePhase { selecting, preparing, checking, uploading, starting, started }

class ImportIntakeState {
  const ImportIntakeState({
    this.pages = const [],
    this.phase = ImportIntakePhase.selecting,
    this.uploaded = 0,
    this.error,
    this.jobId,
  });

  final List<ImportPage> pages;
  final ImportIntakePhase phase;

  /// Files uploaded so far in the current upload.
  final int uploaded;

  /// The last refusal or failure, worded for the user.
  final String? error;

  /// Set once the import has started.
  final String? jobId;

  bool get isPdf => pages.length == 1 && pages.first.type == ImportFileType.pdf;
  bool get hasImages => pages.isNotEmpty && !isPdf;
  bool get isBusy => phase != ImportIntakePhase.selecting && phase != ImportIntakePhase.started;
  bool get canCancel => phase == ImportIntakePhase.checking || phase == ImportIntakePhase.uploading;
  int get totalBytes => pages.fold(0, (sum, p) => sum + p.bytes.length);

  /// Every change replaces [error]: a message only describes the last action.
  ImportIntakeState next({
    List<ImportPage>? pages,
    ImportIntakePhase? phase,
    int? uploaded,
    String? error,
    String? jobId,
  }) => ImportIntakeState(
    pages: pages ?? this.pages,
    phase: phase ?? this.phase,
    uploaded: uploaded ?? this.uploaded,
    error: error,
    jobId: jobId ?? this.jobId,
  );
}

/// Picks, checks and uploads the files for one import, then starts it.
///
/// Every check here is for the user's benefit: it names the limit before an
/// upload is wasted. The server enforces the same rules on the bytes (#82),
/// and the bucket's insert policy runs `ai_import_check()` on every file.
@riverpod
class AiImportIntakeNotifier extends _$AiImportIntakeNotifier {
  bool _cancelRequested = false;

  @override
  ImportIntakeState build() {
    ref.watch(currentAuthUserProvider);
    return const ImportIntakeState();
  }

  // ---------------------------------------------------------------------------
  // Choosing files
  // ---------------------------------------------------------------------------

  Future<void> takePhoto() async {
    if (await _blockedFromAddingImages()) return;
    final XFile? photo;
    try {
      photo = await ref.read(importFilePickerProvider).takePhoto();
    } catch (e) {
      debugPrint('[ai_import] camera failed: $e');
      state = state.next(error: "Couldn't open the camera.");
      return;
    }
    if (photo != null) await addImages([photo]);
  }

  Future<void> chooseImages() async {
    if (await _blockedFromAddingImages()) return;
    final limits = await ref.read(aiImportLimitsProvider.future);
    final List<XFile> picked;
    try {
      picked = await ref.read(importFilePickerProvider).pickImages(limit: limits.maxImages - state.pages.length);
    } catch (e) {
      debugPrint('[ai_import] image picker failed: $e');
      state = state.next(error: "Couldn't open your photos.");
      return;
    }
    if (picked.isNotEmpty) await addImages(picked);
  }

  Future<void> choosePdf() async {
    if (state.isBusy) return;
    if (state.hasImages) {
      state = state.next(error: await _mixMessage('Remove the images to choose a PDF.'));
      return;
    }
    final XFile? pdf;
    try {
      pdf = await ref.read(importFilePickerProvider).pickPdf();
    } catch (e) {
      debugPrint('[ai_import] file picker failed: $e');
      state = state.next(error: "Couldn't open your files.");
      return;
    }
    if (pdf != null) await setPdf(pdf);
  }

  Future<bool> _blockedFromAddingImages() async {
    if (state.isBusy) return true;
    if (state.isPdf) {
      state = state.next(error: await _mixMessage('Remove the PDF to add images.'));
      return true;
    }
    final limits = await ref.read(aiImportLimitsProvider.future);
    if (state.pages.length >= limits.maxImages) {
      state = state.next(error: 'An import can have up to ${limits.maxImages} images.');
      return true;
    }
    return false;
  }

  Future<String> _mixMessage(String fix) async {
    final limits = await ref.read(aiImportLimitsProvider.future);
    return 'An import is either one PDF or up to ${limits.maxImages} images, not both. $fix';
  }

  /// Adds picked images in order, preparing each one. Images that can't be
  /// used are skipped, and the last problem is reported.
  Future<void> addImages(List<XFile> picked) async {
    if (state.isBusy) return;
    if (state.isPdf) {
      state = state.next(error: await _mixMessage('Remove the PDF to add images.'));
      return;
    }
    final limits = await ref.read(aiImportLimitsProvider.future);
    final room = limits.maxImages - state.pages.length;
    String? error;
    var accepted = picked;
    if (picked.length > room) {
      accepted = picked.take(max(room, 0)).toList();
      error = room <= 0
          ? 'An import can have up to ${limits.maxImages} images.'
          : 'An import can have up to ${limits.maxImages} images, so only the first $room were added.';
    }

    state = state.next(phase: ImportIntakePhase.preparing);
    final pages = [...state.pages];
    var total = state.totalBytes;
    for (final file in accepted) {
      final PreparedImage prepared;
      try {
        prepared = await prepareImportImage(await file.readAsBytes(), maxBytes: limits.maxImageBytes);
      } catch (e) {
        debugPrint('[ai_import] preparing ${file.name} failed: $e');
        error = '${_fileName(file, capitalize: true)} couldn\'t be read.';
        continue;
      }
      final bytes = prepared.bytes;
      if (bytes == null) {
        error = switch (prepared.failure!) {
          ImagePrepFailure.unsupported => '${_fileName(file, capitalize: true)} isn\'t a JPEG, PNG or WebP image.',
          ImagePrepFailure.heic =>
            '${_fileName(file, capitalize: true)} is a HEIC photo this device can\'t convert. '
                'Save it as a JPEG and try again.',
          ImagePrepFailure.tooLarge =>
            'Images can be up to ${formatMegabytes(limits.maxImageBytes)}, '
                'and ${_fileName(file)} is still larger after shrinking it.',
        };
        continue;
      }
      if (total + bytes.length > kImportMaxTotalBytes) {
        error =
            'An import can be up to ${formatMegabytes(kImportMaxTotalBytes)} in total. '
            '${_fileName(file, capitalize: true)} wasn\'t added.';
        continue;
      }
      total += bytes.length;
      pages.add(ImportPage(type: prepared.type!, bytes: bytes));
    }
    state = state.next(pages: pages, phase: ImportIntakePhase.selecting, error: error);
  }

  /// Sets the import to a single PDF, if it's within the limits.
  Future<void> setPdf(XFile file) async {
    if (state.isBusy) return;
    if (state.hasImages) {
      state = state.next(error: await _mixMessage('Remove the images to choose a PDF.'));
      return;
    }
    final limits = await ref.read(aiImportLimitsProvider.future);
    final limitText = 'PDFs can be up to ${formatMegabytes(limits.maxPdfBytes)}';

    // Checked before reading, so an enormous file is never loaded.
    final length = await file.length();
    if (length > limits.maxPdfBytes) {
      state = state.next(error: '$limitText, and ${_fileName(file)} is ${formatMegabytes(length)}.');
      return;
    }

    state = state.next(phase: ImportIntakePhase.preparing);
    final bytes = await file.readAsBytes();
    String? error;
    if (detectImportFileType(bytes) != ImportFileType.pdf) {
      error = '${_fileName(file, capitalize: true)} isn\'t a PDF.';
    } else if (bytes.length > limits.maxPdfBytes) {
      error = '$limitText, and ${_fileName(file)} is ${formatMegabytes(bytes.length)}.';
    } else if (bytes.length > kImportMaxTotalBytes) {
      error = 'An import can be up to ${formatMegabytes(kImportMaxTotalBytes)} in total.';
    } else if (isEncryptedPdf(bytes)) {
      error = '${_fileName(file, capitalize: true)} is password protected. Remove the password and try again.';
    } else {
      final pages = countPdfPages(bytes);
      if (pages != null && pages > limits.maxPdfPages) {
        error = 'PDFs can have up to ${limits.maxPdfPages} pages, and ${_fileName(file)} has $pages.';
      }
    }
    state = error == null
        ? state.next(
            pages: [ImportPage(type: ImportFileType.pdf, bytes: bytes)],
            phase: ImportIntakePhase.selecting,
          )
        : state.next(phase: ImportIntakePhase.selecting, error: error);
  }

  void removeAt(int index) {
    if (state.isBusy || index < 0 || index >= state.pages.length) return;
    state = state.next(pages: [...state.pages]..removeAt(index));
  }

  /// Back to an empty import, e.g. to start another after one has started.
  void reset() {
    if (state.isBusy) return;
    state = const ImportIntakeState();
  }

  // ---------------------------------------------------------------------------
  // Uploading
  // ---------------------------------------------------------------------------

  /// Asks to stop an upload. The file in flight finishes (Storage uploads
  /// can't be aborted), then everything uploaded so far is deleted.
  void cancel() {
    if (state.canCancel) _cancelRequested = true;
  }

  /// Checks the user may import, uploads every file, then starts the import.
  /// Any failure before the start deletes what was uploaded.
  Future<void> submit({String? requestedType}) async {
    if (state.pages.isEmpty || state.isBusy) return;
    _cancelRequested = false;
    // Finish (and clean up) even if the screen closes mid-upload.
    final link = ref.keepAlive();
    try {
      await _submit(requestedType);
    } finally {
      link.close();
    }
  }

  Future<void> _submit(String? requestedType) async {
    final pages = state.pages;
    final userId = currentUserId();
    if (userId == null) {
      state = state.next(error: 'Sign in to import files.');
      return;
    }

    state = state.next(phase: ImportIntakePhase.checking, uploaded: 0);
    final AiImportCheck check;
    try {
      check = await checkImport();
    } catch (e) {
      debugPrint('[ai_import] check failed: $e');
      state = state.next(
        phase: ImportIntakePhase.selecting,
        error: "Couldn't check whether you can import right now. Check your connection and try again.",
      );
      return;
    }
    if (!check.allowed) {
      state = state.next(phase: ImportIntakePhase.selecting, error: importCheckMessage(check));
      return;
    }
    if (_cancelRequested) {
      state = state.next(phase: ImportIntakePhase.selecting);
      return;
    }

    final importId = newImportId();
    final uploaded = <String>[];
    state = state.next(phase: ImportIntakePhase.uploading);
    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      // Numbered names: the server reads files in natural order, so this is
      // the page order.
      final path = '$userId/$importId/page-${i + 1}.${page.type.extension}';
      try {
        await uploadFile(path, page.bytes, page.type.contentType);
      } catch (e) {
        debugPrint('[ai_import] upload failed: $e');
        await _removeQuietly(uploaded);
        state = state.next(
          phase: ImportIntakePhase.selecting,
          error: 'The upload failed. Check your connection and try again.',
        );
        return;
      }
      uploaded.add(path);
      state = state.next(uploaded: uploaded.length);
      if (_cancelRequested) {
        await _removeQuietly(uploaded);
        state = state.next(phase: ImportIntakePhase.selecting, uploaded: 0);
        return;
      }
    }

    state = state.next(phase: ImportIntakePhase.starting);
    try {
      final jobId = await startImport(importId, requestedType: requestedType);
      state = ImportIntakeState(phase: ImportIntakePhase.started, jobId: jobId);
      // Home and the Realtime watcher pick the new job up from here.
      ref.invalidate(aiImportJobsProvider);
    } on GenkitFlowException catch (e) {
      // NETWORK and UNKNOWN mean the outcome is unknown: the import may be
      // running and reading these files, so they're left for the cleanup
      // sweep. Any other status is the flow's own answer that nothing started.
      final outcomeKnown = e.status != 'NETWORK' && e.status != 'UNKNOWN';
      if (outcomeKnown) await _removeQuietly(uploaded);
      final refused = const {'FAILED_PRECONDITION', 'RESOURCE_EXHAUSTED', 'INVALID_ARGUMENT'}.contains(e.status);
      state = state.next(
        phase: ImportIntakePhase.selecting,
        error: refused ? importRefusalMessage(e.message) : e.message,
      );
    } catch (e) {
      debugPrint('[ai_import] start failed: $e');
      state = state.next(
        phase: ImportIntakePhase.selecting,
        error: "The import couldn't start. Try again in a moment.",
      );
    }
  }

  Future<void> _removeQuietly(List<String> paths) async {
    if (paths.isEmpty) return;
    try {
      await removeFiles(paths);
    } catch (e) {
      // The cleanup sweep (#87) removes anything left behind.
      debugPrint('[ai_import] removing uploaded files failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Network calls, split out so tests can override them
  // ---------------------------------------------------------------------------

  String? currentUserId() => ref.read(currentAuthUserProvider)?.id;

  Future<AiImportCheck> checkImport() async {
    final result = await Supabase.instance.client.rpc('ai_import_check');
    return AiImportCheck.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<void> uploadFile(String path, Uint8List bytes, String contentType) => Supabase.instance.client.storage
      .from(kAiImportBucket)
      .uploadBinary(path, bytes, fileOptions: FileOptions(contentType: contentType));

  Future<void> removeFiles(List<String> paths) => Supabase.instance.client.storage.from(kAiImportBucket).remove(paths);

  Future<String> startImport(String importId, {String? requestedType}) async {
    final result = await callGenkitFlow(Supabase.instance.client.functions, 'startAiImport', {
      'importId': importId,
      'requestedType': ?requestedType,
    });
    return (result as Map)['jobId'] as String;
  }
}

/// A file's name in quotes for a message, or "that file" when the platform
/// gave it none.
String _fileName(XFile file, {bool capitalize = false}) {
  if (file.name.isNotEmpty) return '"${file.name}"';
  return capitalize ? 'That file' : 'that file';
}

/// A random (version 4) UUID, which the bucket policy requires as the import
/// folder name.
String newImportId([Random? random]) {
  final r = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}
