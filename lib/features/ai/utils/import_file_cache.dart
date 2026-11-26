import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/import_page.dart';
import '../utils/import_file_check.dart';
import 'import_file_cache_memory.dart' if (dart.library.io) 'import_file_cache_io.dart';

part 'import_file_cache.g.dart';

/// An import run in the app with the lifter's own key, kept on this device.
///
/// The files never reach our server on this path, so the device is the only
/// place they exist. They stay until the import is accepted or discarded:
/// a run that fails or is interrupted can be tried again, and a saved one can
/// be re-run as the other type.
class CachedImport {
  const CachedImport({
    required this.importId,
    required this.provider,
    required this.pages,
    this.requestedType,
    this.jobId,
  });

  final String importId;

  /// The `CloudAiProvider` id the run used.
  final String provider;
  final List<ImportPage> pages;
  final String? requestedType;

  /// The saved job, once the result is stored. Null means the run never
  /// finished: it failed, was cancelled, or the app was closed mid-run.
  final String? jobId;

  bool get isPdf => pages.isNotEmpty && pages.every((p) => p.type == ImportFileType.pdf);

  CachedImport saved(String jobId) =>
      CachedImport(importId: importId, provider: provider, pages: pages, requestedType: requestedType, jobId: jobId);

  /// The metadata stored beside the files.
  Map<String, dynamic> toMeta() => {
    'import_id': importId,
    'provider': provider,
    'requested_type': requestedType,
    'job_id': jobId,
    'files': [
      for (final p in pages) {'type': p.type.name, 'name': p.name, 'pdf_pages': p.pdfPages},
    ],
  };

  /// Rebuilds a cached import from [meta] and each file's bytes, in order.
  /// Null when the metadata doesn't describe the files.
  static CachedImport? fromMeta(Map<String, dynamic> meta, List<Uint8List> files) {
    final described = meta['files'];
    if (described is! List || described.length != files.length || files.isEmpty) return null;
    final pages = <ImportPage>[];
    for (var i = 0; i < files.length; i++) {
      final f = described[i];
      if (f is! Map) return null;
      final type = ImportFileType.values.where((t) => t.name == f['type']).firstOrNull;
      if (type == null) return null;
      pages.add(
        ImportPage(type: type, bytes: files[i], name: f['name'] as String?, pdfPages: (f['pdf_pages'] as num?)?.toInt()),
      );
    }
    final importId = meta['import_id'];
    final provider = meta['provider'];
    if (importId is! String || provider is! String) return null;
    return CachedImport(
      importId: importId,
      provider: provider,
      pages: pages,
      requestedType: meta['requested_type'] as String?,
      jobId: meta['job_id'] as String?,
    );
  }
}

/// Where [CachedImport]s are kept: the app's support folder on iOS, Android
/// and desktop, which survives the app being closed, and memory on the web,
/// which doesn't survive a reload (a re-run is then hidden, and an
/// interrupted run can't be offered again).
abstract class ImportFileCache {
  Future<void> save(CachedImport import);
  Future<CachedImport?> load(String importId);

  /// The most recent import whose run never finished, if any.
  Future<CachedImport?> unfinished();
  Future<void> remove(String importId);
}

@Riverpod(keepAlive: true)
ImportFileCache importFileCache(Ref ref) => createImportFileCache();

/// One import's cached files, for the review screen's re-run.
@riverpod
Future<CachedImport?> cachedImport(Ref ref, String importId) async {
  try {
    return await ref.watch(importFileCacheProvider).load(importId);
  } catch (_) {
    return null;
  }
}
