import 'import_file_cache.dart';

ImportFileCache createImportFileCache() => MemoryImportFileCache();

/// Keeps imports for as long as the app runs: the web, and tests.
class MemoryImportFileCache implements ImportFileCache {
  final _imports = <String, CachedImport>{};

  @override
  Future<void> save(CachedImport import) async {
    // Re-inserted so the newest is last.
    _imports.remove(import.importId);
    _imports[import.importId] = import;
  }

  @override
  Future<CachedImport?> load(String importId) async => _imports[importId];

  @override
  Future<CachedImport?> unfinished() async => _imports.values.where((i) => i.jobId == null).lastOrNull;

  @override
  Future<void> remove(String importId) async => _imports.remove(importId);
}
