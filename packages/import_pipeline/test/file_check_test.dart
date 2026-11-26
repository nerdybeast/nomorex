// Ported from supabase/functions/ai/ai_import/file_check_test.ts. The app's
// test/ai/import_file_check_test.dart covers the rest through its re-export.
import 'dart:convert';
import 'dart:typed_data';

import 'package:import_pipeline/import_pipeline.dart';
import 'package:test/test.dart';

Uint8List bytes(List<int> b) => Uint8List.fromList(b);
Uint8List text(String s) => Uint8List.fromList(latin1.encode(s));

void main() {
  test('recognises the four accepted types from their leading bytes', () {
    expect(detectImportFileType(bytes([0xff, 0xd8, 0xff, 0xe0])), ImportFileType.jpeg);
    expect(detectImportFileType(bytes([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0])), ImportFileType.png);
    expect(detectImportFileType(text('RIFF\x00\x00\x00\x00WEBPVP8 ')), ImportFileType.webp);
    expect(detectImportFileType(text('%PDF-1.7\n')), ImportFileType.pdf);
  });

  test('rejects everything else, including near misses', () {
    expect(detectImportFileType(text('MZ\x90\x00 a Windows executable')), isNull);
    expect(detectImportFileType(text('RIFF\x00\x00\x00\x00WAVEfmt ')), isNull);
    expect(detectImportFileType(text('<svg xmlns=')), isNull);
    expect(detectImportFileType(text('%PDF')), isNull);
    expect(detectImportFileType(Uint8List(0)), isNull);
  });

  test('spots a password-protected PDF', () {
    expect(isEncryptedPdf(text('%PDF-1.7 trailer << /Encrypt 5 0 R >>')), true);
    expect(isEncryptedPdf(text('%PDF-1.7 trailer << /Root 1 0 R >>')), false);
  });

  test('each provider has limits, Gemini a smaller total for its inline request cap', () {
    expect(importFileLimitsFor('anthropic/claude-sonnet-5-5').maxTotalBytes, 24000000);
    expect(importFileLimitsFor('googleai/gemini-3.5-flash').maxTotalBytes, lessThan(15000000));
    expect(importFileLimitsFor('unknown/model'), same(kDefaultImportFileLimits));
  });
}
