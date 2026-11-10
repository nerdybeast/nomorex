import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/ai/utils/import_file_check.dart';

Uint8List _bytes(List<int> head, [int padTo = 16]) =>
    Uint8List.fromList([...head, ...List.filled(padTo > head.length ? padTo - head.length : 0, 0)]);

Uint8List _pdf(String body) => Uint8List.fromList(latin1.encode('%PDF-1.7\n$body\n%%EOF'));

void main() {
  group('detectImportFileType', () {
    test('reads the type from the leading bytes', () {
      expect(detectImportFileType(_bytes([0xff, 0xd8, 0xff, 0xe0])), ImportFileType.jpeg);
      expect(detectImportFileType(_bytes([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])), ImportFileType.png);
      expect(
        detectImportFileType(_bytes([...ascii.encode('RIFF'), 1, 2, 3, 4, ...ascii.encode('WEBP')])),
        ImportFileType.webp,
      );
      expect(detectImportFileType(_pdf('')), ImportFileType.pdf);
    });

    test('rejects anything else, including a renamed file and empty input', () {
      expect(detectImportFileType(Uint8List(0)), isNull);
      expect(detectImportFileType(Uint8List.fromList(ascii.encode('GIF89a...'))), isNull);
      expect(detectImportFileType(_bytes([...ascii.encode('RIFF'), 1, 2, 3, 4, ...ascii.encode('WAVE')])), isNull);
    });
  });

  test('isHeic recognises HEIF brands only', () {
    expect(isHeic(_bytes([0, 0, 0, 24, ...ascii.encode('ftypheic')])), isTrue);
    expect(isHeic(_bytes([0, 0, 0, 24, ...ascii.encode('ftypmif1')])), isTrue);
    expect(isHeic(_bytes([0, 0, 0, 24, ...ascii.encode('ftypisom')])), isFalse);
    expect(isHeic(_bytes([0xff, 0xd8, 0xff])), isFalse);
  });

  test('isEncryptedPdf finds the encryption dictionary', () {
    expect(isEncryptedPdf(_pdf('trailer << /Root 1 0 R /Encrypt 5 0 R >>')), isTrue);
    expect(isEncryptedPdf(_pdf('trailer << /Root 1 0 R >>')), isFalse);
  });

  group('countPdfPages', () {
    test('uses the page tree count', () {
      expect(countPdfPages(_pdf('2 0 obj << /Type /Pages /Kids [3 0 R 4 0 R] /Count 12 >> endobj')), 12);
      // Count before Type.
      expect(countPdfPages(_pdf('2 0 obj << /Count 3 /Kids [] /Type /Pages >> endobj')), 3);
    });

    test('takes the largest count when the file was updated incrementally', () {
      expect(
        countPdfPages(
          _pdf(
            '2 0 obj << /Type /Pages /Count 2 >> endobj\n'
            '2 0 obj << /Type /Pages /Count 14 >> endobj',
          ),
        ),
        14,
      );
    });

    test('prefers the linearization count', () {
      expect(countPdfPages(_pdf('1 0 obj << /Linearized 1 /L 5000 /N 7 /T 4000 >> endobj')), 7);
    });

    test('falls back to counting page objects, ignoring the page tree', () {
      expect(
        countPdfPages(
          _pdf(
            '3 0 obj << /Type /Page >> endobj 4 0 obj << /Type/Page >> endobj '
            '5 0 obj << /Type /PageLabel >> endobj',
          ),
        ),
        2,
      );
    });

    test('returns null when pages are hidden in compressed streams', () {
      expect(
        countPdfPages(_pdf('7 0 obj << /Type /ObjStm /N 40 /Filter /FlateDecode >> stream ... endstream')),
        isNull,
      );
    });
  });

  test('formatMegabytes never rounds a file down to the limit', () {
    expect(formatMegabytes(7000000), '7 MB');
    expect(formatMegabytes(20000000), '20 MB');
    expect(formatMegabytes(20400000), '20.4 MB');
    expect(formatMegabytes(2460000), '2.5 MB');
  });
}
