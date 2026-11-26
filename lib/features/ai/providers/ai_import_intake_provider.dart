import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:genkit/genkit.dart';
import 'package:image_picker/image_picker.dart';
import 'package:import_pipeline/import_pipeline.dart'
    show CatalogExercise, ImportFile, ImportFileProblem, ImportFileRejected, ImportRunCutOff, ImportRunInvalidOutput,
        ImportRunNoWorkout, ImportRunOk, ImportRunOutcome, ImportType, runImport;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../auth/providers/auth_provider.dart';
import '../../exercises/providers/exercises_provider.dart';
import '../core/ai_provider.dart';
import '../core/ai_provider_exception.dart';
import '../core/ai_task.dart';
import '../core/genkit_provider.dart';
import '../core/model_router_provider.dart';
import '../models/ai_import_limits.dart';
import '../models/import_page.dart';
import '../utils/import_file_cache.dart';
import '../utils/genkit_call.dart';
import '../utils/import_file_check.dart';
import '../utils/import_file_picker.dart';
import '../utils/import_image_prep.dart';
import '../utils/import_messages.dart';
import 'ai_import_jobs_provider.dart';
import 'ai_import_path_provider.dart';
import '../../analytics/analytics.dart';
import '../../analytics/providers/analytics_provider.dart';

export '../models/import_page.dart';

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
      .select('enabled, max_images, max_pdf_pages, max_image_bytes, max_pdf_bytes, max_job_seconds')
      .single();
  return AiImportLimits.fromJson(row);
}

/// Where an import is. The hosted path checks, uploads and starts; a local
/// run reads in the app ([reading]), then stores the result ([saving]), and
/// stops at [failed] when it can't finish, with the files kept to try again.
enum ImportIntakePhase { selecting, preparing, checking, uploading, starting, reading, saving, failed, started }

/// What the lifter can do about a failed local run, besides discarding it.
enum ImportFailureAction {
  /// Read the same files again.
  tryAgain,

  /// The key was refused: open the AI assistant settings.
  checkKey,

  /// Out of credit or quota: try later, or choose another provider.
  switchProvider,

  /// Nothing to do but discard (no workout found in the files).
  none,
}

/// Why a local run stopped, worded for the lifter. Never the provider's own
/// error.
class ImportFailure {
  const ImportFailure(this.title, this.message, {this.action = ImportFailureAction.tryAgain});

  final String title;
  final String message;
  final ImportFailureAction action;
}

class ImportIntakeState {
  const ImportIntakeState({
    this.pages = const [],
    this.phase = ImportIntakePhase.selecting,
    this.uploaded = 0,
    this.error,
    this.jobId,
    this.importId,
    this.provider,
    this.requestedType,
    this.readingSince,
    this.failure,
  });

  final List<ImportPage> pages;
  final ImportIntakePhase phase;

  /// Files uploaded so far in the current upload.
  final int uploaded;

  /// The last refusal or failure, worded for the user.
  final String? error;

  /// Set once the import has started (hosted) or its result is saved (local).
  final String? jobId;

  /// A local run's import, set from its first try so retries and the cached
  /// files share it.
  final String? importId;

  /// The provider reading a local run, from its first try. Null on the
  /// hosted path.
  final CloudAiProvider? provider;

  /// `workout` or `program` when the lifter asked for one (a re-run).
  final String? requestedType;

  /// When the model call started, for the elapsed time.
  final DateTime? readingSince;

  /// Why the last local run stopped, while [phase] is failed.
  final ImportFailure? failure;

  /// An import is all PDFs or all images, never a mix.
  bool get isPdf => pages.isNotEmpty && pages.every((p) => p.type == ImportFileType.pdf);
  bool get hasImages => pages.any((p) => p.type.isImage);

  /// The PDFs' pages added up, counting only the ones whose count is known.
  int get pdfPageTotal => pages.fold(0, (sum, p) => sum + (p.pdfPages ?? 0));

  /// Whether every PDF's page count is known, so [pdfPageTotal] is exact.
  bool get pdfPagesKnown => isPdf && pages.every((p) => p.pdfPages != null);
  bool get isBusy =>
      phase != ImportIntakePhase.selecting && phase != ImportIntakePhase.started && phase != ImportIntakePhase.failed;
  bool get canCancel =>
      phase == ImportIntakePhase.checking || phase == ImportIntakePhase.uploading || phase == ImportIntakePhase.reading;

  /// A local run in flight.
  bool get isRunningLocally => phase == ImportIntakePhase.reading || phase == ImportIntakePhase.saving;
  int get totalBytes => pages.fold(0, (sum, p) => sum + p.bytes.length);

  /// Every change replaces [error]: a message only describes the last action.
  ImportIntakeState next({
    List<ImportPage>? pages,
    ImportIntakePhase? phase,
    int? uploaded,
    String? error,
    String? jobId,
    DateTime? readingSince,
    ImportFailure? failure,
  }) => ImportIntakeState(
    pages: pages ?? this.pages,
    phase: phase ?? this.phase,
    uploaded: uploaded ?? this.uploaded,
    error: error,
    jobId: jobId ?? this.jobId,
    importId: importId,
    provider: provider,
    requestedType: requestedType,
    readingSince: readingSince ?? this.readingSince,
    failure: failure,
  );

  /// A local run of [pages], about to start.
  ImportIntakeState reading({
    required String importId,
    required CloudAiProvider provider,
    String? requestedType,
  }) => ImportIntakeState(
    pages: pages,
    phase: ImportIntakePhase.reading,
    importId: importId,
    provider: provider,
    requestedType: requestedType,
    readingSince: DateTime.now(),
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
  CancellationController? _localRun;

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
    final limits = await ref.read(aiImportIntakeLimitsProvider.future);
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

  Future<void> choosePdfs() async {
    if (state.isBusy) return;
    if (state.hasImages) {
      state = state.next(error: await _mixMessage('Remove the images to add PDFs.'));
      return;
    }
    final limits = await ref.read(aiImportIntakeLimitsProvider.future);
    if (state.pages.length >= limits.maxPdfPages) {
      state = state.next(error: 'PDFs can have up to ${limits.maxPdfPages} pages in total.');
      return;
    }
    final List<XFile> picked;
    try {
      picked = await ref.read(importFilePickerProvider).pickPdfs();
    } catch (e) {
      debugPrint('[ai_import] file picker failed: $e');
      state = state.next(error: "Couldn't open your files.");
      return;
    }
    if (picked.isNotEmpty) await addPdfs(picked);
  }

  Future<bool> _blockedFromAddingImages() async {
    if (state.isBusy) return true;
    if (state.isPdf) {
      state = state.next(error: await _mixMessage('Remove the PDFs to add images.'));
      return true;
    }
    final limits = await ref.read(aiImportIntakeLimitsProvider.future);
    if (state.pages.length >= limits.maxImages) {
      state = state.next(error: 'An import can have up to ${limits.maxImages} images.');
      return true;
    }
    return false;
  }

  Future<String> _mixMessage(String fix) async {
    final limits = await ref.read(aiImportIntakeLimitsProvider.future);
    return 'An import is either PDFs or up to ${limits.maxImages} images, not both. $fix';
  }

  /// Adds picked images in order, preparing each one. Images that can't be
  /// used are skipped, and the last problem is reported.
  Future<void> addImages(List<XFile> picked) async {
    if (state.isBusy) return;
    if (state.isPdf) {
      state = state.next(error: await _mixMessage('Remove the PDFs to add images.'));
      return;
    }
    final limits = await ref.read(aiImportIntakeLimitsProvider.future);
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
      if (total + bytes.length > limits.maxTotalBytes) {
        error =
            'An import can be up to ${formatMegabytes(limits.maxTotalBytes)} in total. '
            '${_fileName(file, capitalize: true)} wasn\'t added.';
        continue;
      }
      total += bytes.length;
      pages.add(ImportPage(type: prepared.type!, bytes: bytes));
    }
    state = state.next(pages: pages, phase: ImportIntakePhase.selecting, error: error);
  }

  /// Adds picked PDFs, sorted by name in natural order ("week 2" before
  /// "week 10"), after any already chosen. Each is checked on its own; one
  /// that can't be used is skipped, and the last problem is reported.
  ///
  /// The page cap covers the whole import, not each file: the model's output
  /// budget is per import, so ten one-page PDFs and one ten-page PDF cost
  /// about the same. A PDF has at least one page, so the cap also bounds
  /// the number of files.
  Future<void> addPdfs(List<XFile> picked) async {
    if (state.isBusy) return;
    if (state.hasImages) {
      state = state.next(error: await _mixMessage('Remove the images to add PDFs.'));
      return;
    }
    final limits = await ref.read(aiImportIntakeLimitsProvider.future);
    final sizeLimit = 'PDFs can be up to ${formatMegabytes(limits.maxPdfBytes)}';
    final pageLimit = 'PDFs can have up to ${limits.maxPdfPages} pages in total';
    final sorted = [...picked]..sort((a, b) => compareNatural(a.name, b.name));

    state = state.next(phase: ImportIntakePhase.preparing);
    final pages = [...state.pages];
    var total = state.totalBytes;
    var pageTotal = state.pdfPageTotal;
    String? error;
    for (final file in sorted) {
      if (pages.length >= limits.maxPdfPages) {
        error = '$pageLimit. ${_fileName(file, capitalize: true)} wasn\'t added.';
        continue;
      }
      // Checked before reading, so an enormous file is never loaded.
      final length = await file.length();
      if (length > limits.maxPdfBytes) {
        error = '$sizeLimit, and ${_fileName(file)} is ${formatMegabytes(length)}.';
        continue;
      }
      if (file.name.isNotEmpty && pages.any((p) => p.name == file.name && p.bytes.length == length)) {
        error = '${_fileName(file, capitalize: true)} is already added.';
        continue;
      }

      final Uint8List bytes;
      try {
        bytes = await file.readAsBytes();
      } catch (e) {
        debugPrint('[ai_import] reading ${file.name} failed: $e');
        error = '${_fileName(file, capitalize: true)} couldn\'t be read.';
        continue;
      }
      if (detectImportFileType(bytes) != ImportFileType.pdf) {
        error = '${_fileName(file, capitalize: true)} isn\'t a PDF.';
        continue;
      }
      if (bytes.length > limits.maxPdfBytes) {
        error = '$sizeLimit, and ${_fileName(file)} is ${formatMegabytes(bytes.length)}.';
        continue;
      }
      if (isEncryptedPdf(bytes)) {
        error = '${_fileName(file, capitalize: true)} is password protected. Remove the password and try again.';
        continue;
      }
      final count = countPdfPages(bytes);
      if (count != null && pageTotal + count > limits.maxPdfPages) {
        error = pages.isEmpty
            ? '$pageLimit, and ${_fileName(file)} has $count.'
            : '$pageLimit, and ${_fileName(file)} would make ${pageTotal + count}. It wasn\'t added.';
        continue;
      }
      if (total + bytes.length > limits.maxTotalBytes) {
        error =
            'An import can be up to ${formatMegabytes(limits.maxTotalBytes)} in total. '
            '${_fileName(file, capitalize: true)} wasn\'t added.';
        continue;
      }
      total += bytes.length;
      pageTotal += count ?? 0;
      pages.add(
        ImportPage(
          type: ImportFileType.pdf,
          bytes: bytes,
          name: file.name.isEmpty ? null : file.name,
          pdfPages: count,
        ),
      );
    }
    state = state.next(pages: pages, phase: ImportIntakePhase.selecting, error: error);
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

  /// Asks to stop an upload or a local run. An upload's file in flight
  /// finishes (Storage uploads can't be aborted), then everything uploaded so
  /// far is deleted. A local run's model call is aborted, and the files stay
  /// chosen.
  void cancel() {
    if (!state.canCancel) return;
    _cancelRequested = true;
    _localRun?.cancel('cancelled by the lifter');
  }

  /// Starts the import on whichever path is open: in the app with the
  /// lifter's key ([runLocally]) when one is set, else the hosted alpha.
  Future<void> submit({String? requestedType}) async {
    if (ref.read(modelForTaskProvider(AiTask.import)) != null) return runLocally(requestedType: requestedType);
    return submitHosted(requestedType: requestedType);
  }

  /// Checks the user may import, uploads every file, then starts the import.
  /// Any failure before the start deletes what was uploaded.
  Future<void> submitHosted({String? requestedType}) async {
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
      ref.read(analyticsProvider).logEvent(AnalyticsEvents.aiImportStarted, {
        'requested_type': requestedType ?? 'auto',
        'rerun': 0,
        'provider': 'hosted',
      });
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
  // Running in the app, with the lifter's own key
  // ---------------------------------------------------------------------------

  /// Reads the chosen files with the lifter's own provider, stores the result
  /// with `ai_import_save_result` and ends at [ImportIntakePhase.started] with
  /// the job to review. The files are kept on this device first, so a run that
  /// fails, is cancelled or is cut short by the app closing can be tried
  /// again, and a saved one re-run as the other type.
  ///
  /// A retry keeps the first try's import, provider choice aside: a new key
  /// or provider chosen since is used.
  Future<void> runLocally({String? requestedType}) async {
    if (state.pages.isEmpty || state.isBusy) return;
    final route = ref.read(modelForTaskProvider(AiTask.import));
    final cloud = route?.cloud;
    if (route == null || cloud == null) {
      state = state.next(phase: ImportIntakePhase.selecting, error: 'Add an AI key to import.');
      return;
    }
    if (currentUserId() == null) {
      state = state.next(error: 'Sign in to import files.');
      return;
    }
    requestedType ??= state.requestedType;
    final importId = state.importId ?? newImportId();
    final rerun = state.jobId != null;
    state = state.reading(importId: importId, provider: cloud, requestedType: requestedType);
    _cancelRequested = false;
    final controller = _localRun = CancellationController();
    // Finish (and save) even if the screen closes mid-run.
    final link = ref.keepAlive();
    try {
      await _keepAwake(true);
      await _cacheQuietly(
        CachedImport(importId: importId, provider: cloud.id, pages: state.pages, requestedType: requestedType),
      );
      ref.read(analyticsProvider).logEvent(AnalyticsEvents.aiImportStarted, {
        'requested_type': requestedType ?? 'auto',
        'rerun': rerun ? 1 : 0,
        'provider': cloud.id,
      });
      final outcome = await readFiles(
        modelName: route.modelName,
        provider: cloud,
        pages: state.pages,
        requestedType: requestedType,
        cancel: controller.token,
      );
      if (controller.isCancelled) throw AiProviderException(AiErrorCode.cancelled, provider: cloud);
      switch (outcome) {
        case ImportRunOk(:final result, :final detectedType, :final usage):
          state = state.next(phase: ImportIntakePhase.saving);
          final jobId = await saveResult(
            importId: importId,
            detectedType: detectedType.name,
            result: result,
            provider: cloud,
            requestedType: requestedType,
            model: route.modelName,
            inputTokens: usage?.inputTokens,
            outputTokens: usage?.outputTokens,
          );
          await _cacheQuietly(
            CachedImport(
              importId: importId,
              provider: cloud.id,
              pages: state.pages,
              requestedType: requestedType,
              jobId: jobId,
            ),
          );
          state = ImportIntakeState(
            phase: ImportIntakePhase.started,
            jobId: jobId,
            importId: importId,
            provider: cloud,
          );
          ref.invalidate(aiImportJobsProvider);
        case ImportRunNoWorkout():
          _fail(
            ImportFailure(
              "We couldn't find a workout or program",
              '${cloud.label} read the files but found no training in them. Check they are the right files.',
              action: ImportFailureAction.none,
            ),
          );
        case ImportRunInvalidOutput():
          _fail(
            ImportFailure(
              "The import didn't finish",
              "${cloud.label}'s answer couldn't be read. Trying again usually works.",
            ),
          );
        case ImportRunCutOff():
          _fail(
            ImportFailure(
              'Too much to read in one go',
              'There was more in these files than ${cloud.label} can answer at once. '
                  'Try fewer pages, such as one block or a few weeks at a time.',
              action: ImportFailureAction.none,
            ),
          );
      }
    } on ImportFileRejected catch (e) {
      _fail(ImportFailure("These files can't be read", _rejectionMessage(e, cloud), action: ImportFailureAction.none));
    } on PostgrestException catch (e) {
      debugPrint('[ai_import] saving the result failed: ${e.code} ${e.message}');
      _fail(
        e.message.startsWith('too_many_pending')
            ? const ImportFailure(
                'Too many imports waiting',
                'You have 20 imports waiting for review. Review or discard one on Home, then try again.',
              )
            : const ImportFailure(
                "The import couldn't be saved",
                'It was read, but saving it failed. Check your connection and try again.',
              ),
      );
    } catch (e) {
      final error = controller.isCancelled
          ? AiProviderException(AiErrorCode.cancelled, provider: cloud)
          : aiExceptionFrom(e, provider: cloud);
      if (error.code == AiErrorCode.cancelled) {
        // Back to the chosen files. Nothing was saved, so nothing is kept.
        await _removeCachedQuietly(importId);
        state = ImportIntakeState(pages: state.pages);
      } else {
        debugPrint('[ai_import] local run failed: $error');
        _fail(importFailureFor(error, cloud));
      }
    } finally {
      _localRun = null;
      await _keepAwake(false);
      link.close();
    }
  }

  /// Offers a run that never finished: the app was closed while it was
  /// reading. Does nothing once files are chosen or a run is under way.
  Future<void> restoreUnfinished() async {
    if (state.pages.isNotEmpty || state.isBusy || state.phase == ImportIntakePhase.started) return;
    final CachedImport? cached;
    try {
      cached = await ref.read(importFileCacheProvider).unfinished();
    } catch (e) {
      debugPrint('[ai_import] reading cached imports failed: $e');
      return;
    }
    if (cached == null || state.pages.isNotEmpty || state.isBusy) return;
    final provider = CloudAiProvider.fromId(cached.provider);
    final count = cached.pages.length;
    final what = cached.isPdf ? (count == 1 ? 'PDF' : '$count PDFs') : (count == 1 ? 'photo' : '$count photos');
    state = ImportIntakeState(
      pages: cached.pages,
      phase: ImportIntakePhase.failed,
      importId: cached.importId,
      provider: provider,
      requestedType: cached.requestedType,
      failure: ImportFailure(
        'The import stopped',
        'NoMoreX was closed while ${provider?.label ?? 'the AI'} was reading. Your $what '
            '${count == 1 ? 'is' : 'are'} still on this device, so you can try again.',
      ),
    );
  }

  /// Reads a saved import's files again as [requestedType], from this
  /// device's copy. Returns false, changing nothing, when the device no longer
  /// has them. The new result replaces the import's current one.
  Future<bool> rerunFromCache(String importId, String requestedType) async {
    if (state.isBusy) return false;
    // The screen that asks isn't watching this provider yet.
    final link = ref.keepAlive();
    try {
      final CachedImport? cached;
      try {
        cached = await ref.read(importFileCacheProvider).load(importId);
      } catch (_) {
        return false;
      }
      if (cached == null || state.isBusy) return false;
      state = ImportIntakeState(
        pages: cached.pages,
        importId: cached.importId,
        provider: CloudAiProvider.fromId(cached.provider),
        requestedType: requestedType,
        jobId: cached.jobId,
      );
      unawaited(runLocally(requestedType: requestedType));
      return true;
    } finally {
      link.close();
    }
  }

  /// From a failed or interrupted run back to its files, to change them
  /// before trying again. The run keeps its import, so the cached copy is
  /// replaced on the next try.
  void backToFiles() {
    if (state.phase != ImportIntakePhase.failed) return;
    state = state.next(phase: ImportIntakePhase.selecting);
  }

  /// Gives up on a failed or interrupted run: its files leave this device.
  Future<void> discardRun() async {
    if (state.isBusy) return;
    final importId = state.importId;
    state = const ImportIntakeState();
    if (importId != null) await _removeCachedQuietly(importId);
  }

  void _fail(ImportFailure failure) => state = state.next(phase: ImportIntakePhase.failed, failure: failure);

  Future<void> _cacheQuietly(CachedImport import) async {
    try {
      await ref.read(importFileCacheProvider).save(import);
    } catch (e) {
      // The run goes ahead; only a retry after the app closes is lost.
      debugPrint('[ai_import] caching the files failed: $e');
    }
  }

  Future<void> _removeCachedQuietly(String importId) async {
    try {
      await ref.read(importFileCacheProvider).remove(importId);
    } catch (e) {
      debugPrint('[ai_import] removing cached files failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Network calls, split out so tests can override them
  // ---------------------------------------------------------------------------

  /// Reads [pages] with [modelName] through the import pipeline, retrying
  /// provider outages the way `generateWithRoute` does.
  Future<ImportRunOutcome> readFiles({
    required String modelName,
    required CloudAiProvider provider,
    required List<ImportPage> pages,
    required CancellationToken cancel,
    String? requestedType,
  }) async {
    final ai = await ref.read(genkitProvider.future);
    final exercises = await ref.read(exercisesProvider.future);
    return runImport(
      ai,
      modelName: modelName,
      files: [for (final p in pages) ImportFile(p.bytes, name: p.name)],
      catalog: [
        for (final e in exercises)
          CatalogExercise(
            id: e.id,
            name: e.name,
            aliases: e.aliases,
            isPredefined: e.isPredefined,
            retiredAt: e.retiredAt?.toIso8601String(),
            createdAt: e.createdAt?.toUtc().toIso8601String(),
          ),
      ],
      requestedType: ImportType.values.where((t) => t.name == requestedType).firstOrNull,
      cancel: cancel,
      use: [
        retry(
          maxRetries: 3,
          statuses: const [StatusCode.unavailable, StatusCode.deadlineExceeded, StatusCode.internal],
          initialDelay: const Duration(seconds: 2),
          maxDelay: const Duration(seconds: 20),
        ),
      ],
    ).timeout(const Duration(minutes: 6));
  }

  /// Stores the result as a `ready` job and returns its ID.
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
    final jobId = await Supabase.instance.client.rpc(
      'ai_import_save_result',
      params: {
        'p_import_id': importId,
        'p_detected_type': detectedType,
        'p_result': result,
        'p_provider': provider.id,
        'p_requested_type': requestedType,
        'p_model': model,
        'p_input_tokens': inputTokens,
        'p_output_tokens': outputTokens,
      },
    );
    return jobId as String;
  }

  /// Keeps the screen on while the model reads: a phone that locks mid-run
  /// suspends the app, and the request with it.
  Future<void> keepScreenOn(bool on) => on ? WakelockPlus.enable() : WakelockPlus.disable();

  Future<void> _keepAwake(bool on) async {
    try {
      await keepScreenOn(on);
    } catch (e) {
      debugPrint('[ai_import] wakelock: $e');
    }
  }


  String? currentUserId() => ref.read(currentAuthUserProvider)?.id;

  Future<AiImportCheck> checkImport() async {
    final result = await Supabase.instance.client.rpc('ai_import_check');
    return AiImportCheck.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<void> uploadFile(String path, Uint8List bytes, String contentType) => Supabase.instance.client.storage
      .from(kAiImportBucket)
      .uploadBinary(path, bytes, fileOptions: FileOptions(contentType: contentType));

  Future<void> removeFiles(List<String> paths) => Supabase.instance.client.storage.from(kAiImportBucket).remove(paths);

  Future<String> startImport(String importId, {String? requestedType}) =>
      callStartAiImport(importId, requestedType: requestedType);
}

/// Starts the AI run over files already uploaded for [importId] and returns
/// its job ID. Runs it again when the import has a ready or failed job, which
/// is how a re-run as the other type works. Throws [GenkitFlowException].
Future<String> callStartAiImport(String importId, {String? requestedType}) async {
  final result = await callGenkitFlow(Supabase.instance.client.functions, 'startAiImport', {
    'importId': importId,
    'requestedType': ?requestedType,
  });
  return (result as Map)['jobId'] as String;
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

/// What the lifter sees when a local run fails with [error]. The wording
/// follows the mockups' "other causes" note; the provider's error never shows.
ImportFailure importFailureFor(AiProviderException error, CloudAiProvider provider) {
  final name = provider.label;
  return switch (error.code) {
    AiErrorCode.invalidKey => ImportFailure(
      "$name didn't accept your key",
      'Check the key in AI assistant settings, then try again. Your files are still on this device.',
      action: ImportFailureAction.checkKey,
    ),
    AiErrorCode.billing => ImportFailure(
      'Your $name quota is used up for now',
      'Your $name account is out of credit or over its usage limit. Try again later, '
          'or choose another provider in AI assistant settings.',
      action: ImportFailureAction.switchProvider,
    ),
    AiErrorCode.rateLimited => ImportFailure('$name is busy', 'Try again in a minute.'),
    AiErrorCode.network => const ImportFailure(
      "You're offline",
      'Your files are saved on this device. Try again when you\'re back online.',
    ),
    AiErrorCode.tooLong => ImportFailure(
      'Too much to read in one go',
      'There was more in these files than $name can take at once. '
          'Try fewer pages, such as one block or a few weeks at a time.',
      action: ImportFailureAction.none,
    ),
    _ => ImportFailure("The import didn't finish", error.message),
  };
}

String _rejectionMessage(ImportFileRejected e, CloudAiProvider provider) {
  final name = e.file?.name == null ? 'One of the files' : '"${e.file!.name}"';
  return switch (e.problem) {
    ImportFileProblem.tooLarge || ImportFileProblem.tooLargeInTotal =>
      'These files are larger than ${provider.label} takes in one import. Remove some and try again.',
    ImportFileProblem.tooMany || ImportFileProblem.tooManyPages =>
      'That\'s more pages than ${provider.label} takes in one import. Remove some and try again.',
    ImportFileProblem.encrypted => '$name is password protected. Remove the password and try again.',
    ImportFileProblem.mixed => 'An import is either PDFs or images, not both.',
    _ => '$name isn\'t a JPEG, PNG, WebP or PDF.',
  };
}
