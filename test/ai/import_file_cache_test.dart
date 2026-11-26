import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/ai/models/import_page.dart';
import 'package:nomorex/features/ai/utils/import_file_cache.dart';
import 'package:nomorex/features/ai/utils/import_file_cache_io.dart';
import 'package:nomorex/features/ai/utils/import_file_check.dart';

const _a = '11111111-1111-4111-8111-111111111111';
const _b = '22222222-2222-4222-8222-222222222222';

ImportPage _page(ImportFileType type, List<int> bytes, {String? name, int? pdfPages}) =>
    ImportPage(type: type, bytes: Uint8List.fromList(bytes), name: name, pdfPages: pdfPages);

void main() {
  late Directory root;
  late DirectoryImportFileCache cache;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('ai_imports');
    cache = DirectoryImportFileCache(root: () async => root);
  });
  tearDown(() => root.delete(recursive: true));

  test('keeps the files, their order and what they are across a restart', () async {
    await cache.save(
      CachedImport(
        importId: _a,
        provider: 'gemini',
        requestedType: 'program',
        pages: [
          _page(ImportFileType.pdf, [1, 2, 3], name: 'week 1.pdf', pdfPages: 2),
          _page(ImportFileType.pdf, [4, 5], name: 'week 2.pdf'),
        ],
      ),
    );
    final again = await DirectoryImportFileCache(root: () async => root).load(_a);
    expect(again!.provider, 'gemini');
    expect(again.requestedType, 'program');
    expect(again.jobId, isNull);
    expect([for (final p in again.pages) p.bytes], [
      [1, 2, 3],
      [4, 5],
    ]);
    expect(again.pages.first.name, 'week 1.pdf');
    expect(again.pages.first.pdfPages, 2);
    expect(again.isPdf, isTrue);
  });

  test('finds the newest unfinished run, and not a saved one', () async {
    await cache.save(CachedImport(importId: _a, provider: 'openai', pages: [_page(ImportFileType.jpeg, [1])]));
    await cache.save(
      CachedImport(importId: _b, provider: 'gemini', pages: [_page(ImportFileType.png, [2])], jobId: 'job-1'),
    );
    expect((await cache.unfinished())?.importId, _a);

    await cache.save(CachedImport(importId: _a, provider: 'openai', pages: [_page(ImportFileType.jpeg, [1])], jobId: 'j'));
    expect(await cache.unfinished(), isNull);
  });

  test('a save after the files changed leaves none of the old ones', () async {
    await cache.save(
      CachedImport(
        importId: _a,
        provider: 'gemini',
        pages: [_page(ImportFileType.jpeg, [1]), _page(ImportFileType.jpeg, [2])],
      ),
    );
    await cache.save(CachedImport(importId: _a, provider: 'gemini', pages: [_page(ImportFileType.webp, [9])]));
    final files = Directory('${root.path}/$_a').listSync().map((f) => f.uri.pathSegments.last).toSet();
    expect(files, {'page-1.webp', 'meta.json'});
    expect((await cache.load(_a))!.pages.single.bytes, [9]);
  });

  test('removing an import deletes its folder; other ids are never paths', () async {
    await cache.save(CachedImport(importId: _a, provider: 'gemini', pages: [_page(ImportFileType.jpeg, [1])]));
    await cache.remove(_a);
    expect(await cache.load(_a), isNull);
    expect(Directory('${root.path}/$_a').existsSync(), isFalse);
    await cache.remove(_a);
    expect(() => cache.load('../../etc'), throwsArgumentError);
  });
}
