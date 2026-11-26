import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'import_file_cache.dart';

ImportFileCache createImportFileCache() => DirectoryImportFileCache();

/// Keeps each import in `<app support>/ai_imports/<import id>/`: its files as
/// `page-N.<ext>` and `meta.json` beside them. The support folder isn't
/// cleared by the system the way the caches folder can be, and isn't shown
/// to the user.
class DirectoryImportFileCache implements ImportFileCache {
  DirectoryImportFileCache({Future<Directory> Function()? root}) : _root = root ?? _defaultRoot;

  final Future<Directory> Function() _root;

  static Future<Directory> _defaultRoot() async =>
      Directory('${(await getApplicationSupportDirectory()).path}/ai_imports');

  /// Import ids are UUIDs the app made; anything else is never a folder name.
  static final _validId = RegExp(r'^[0-9a-f-]{36}$');

  Future<Directory> _folder(String importId) async {
    if (!_validId.hasMatch(importId)) throw ArgumentError.value(importId, 'importId');
    return Directory('${(await _root()).path}/$importId');
  }

  @override
  Future<void> save(CachedImport import) async {
    final folder = await _folder(import.importId);
    await folder.create(recursive: true);
    // The files may have changed since the last save (a retry after "Change
    // files"), so they're written afresh.
    await for (final entry in folder.list()) {
      if (entry is File) await entry.delete();
    }
    for (var i = 0; i < import.pages.length; i++) {
      final page = import.pages[i];
      await File('${folder.path}/page-${i + 1}.${page.type.extension}').writeAsBytes(page.bytes, flush: true);
    }
    // The metadata last, so a folder without it is a save that never finished.
    await File('${folder.path}/meta.json').writeAsString(jsonEncode(import.toMeta()), flush: true);
  }

  @override
  Future<CachedImport?> load(String importId) async {
    final folder = await _folder(importId);
    return _read(folder);
  }

  Future<CachedImport?> _read(Directory folder) async {
    final metaFile = File('${folder.path}/meta.json');
    if (!await metaFile.exists()) return null;
    try {
      final meta = jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
      final files = (meta['files'] as List?) ?? const [];
      final bytes = <Uint8List>[];
      for (var i = 0; i < files.length; i++) {
        final type = (files[i] as Map)['type'];
        final ext = type == 'jpeg' ? 'jpg' : type;
        bytes.add(await File('${folder.path}/page-${i + 1}.$ext').readAsBytes());
      }
      return CachedImport.fromMeta(meta, bytes);
    } catch (e) {
      debugPrint('[ai_import] cached import ${folder.path} unreadable: $e');
      return null;
    }
  }

  @override
  Future<CachedImport?> unfinished() async {
    final root = await _root();
    if (!await root.exists()) return null;
    final candidates = <(DateTime, Directory)>[];
    await for (final entry in root.list()) {
      if (entry is! Directory) continue;
      final meta = File('${entry.path}/meta.json');
      if (await meta.exists()) candidates.add((await meta.lastModified(), entry));
    }
    candidates.sort((a, b) => b.$1.compareTo(a.$1));
    for (final (_, folder) in candidates) {
      final cached = await _read(folder);
      if (cached != null && cached.jobId == null) return cached;
    }
    return null;
  }

  @override
  Future<void> remove(String importId) async {
    final folder = await _folder(importId);
    if (await folder.exists()) await folder.delete(recursive: true);
  }
}
