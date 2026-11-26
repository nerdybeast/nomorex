import 'dart:convert';
import 'dart:typed_data';

/// The four file types an import accepts.
enum ImportFileType {
  jpeg('image/jpeg', 'jpg'),
  png('image/png', 'png'),
  webp('image/webp', 'webp'),
  pdf('application/pdf', 'pdf');

  const ImportFileType(this.contentType, this.extension);

  final String contentType;
  final String extension;

  bool get isImage => this != pdf;
}

bool _startsWith(Uint8List bytes, List<int> signature, [int offset = 0]) {
  if (bytes.length < offset + signature.length) return false;
  for (var i = 0; i < signature.length; i++) {
    if (bytes[offset + i] != signature[i]) return false;
  }
  return true;
}

/// The file's real type from its leading bytes, or null if it isn't one of
/// the accepted types. The name and declared type are never consulted,
/// because both come from wherever the file came from. Mirrors
/// `detectFileType` in `supabase/functions/ai/ai_import/file_check.ts`.
ImportFileType? detectImportFileType(Uint8List bytes) {
  if (_startsWith(bytes, const [0xff, 0xd8, 0xff])) return ImportFileType.jpeg;
  if (_startsWith(bytes, const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) return ImportFileType.png;
  // "RIFF", a four-byte size, then "WEBP".
  if (_startsWith(bytes, const [0x52, 0x49, 0x46, 0x46]) && _startsWith(bytes, const [0x57, 0x45, 0x42, 0x50], 8)) {
    return ImportFileType.webp;
  }
  if (_startsWith(bytes, const [0x25, 0x50, 0x44, 0x46, 0x2d])) return ImportFileType.pdf; // "%PDF-"
  return null;
}

/// Whether the bytes are a HEIC/HEIF photo, which no provider accepts and the
/// app can only convert where the platform picker does it.
bool isHeic(Uint8List bytes) {
  // An ISO-BMFF "ftyp" box at offset 4, then a HEIF brand.
  if (!_startsWith(bytes, const [0x66, 0x74, 0x79, 0x70], 4) || bytes.length < 12) return false;
  final brand = latin1.decode(bytes.sublist(8, 12));
  return const {'heic', 'heix', 'hevc', 'hevx', 'heim', 'heis', 'mif1', 'msf1'}.contains(brand);
}

/// Whether a PDF is password protected, which no provider can read. Searches
/// for the marker rather than parsing, because the file is untrusted (the
/// same search as `isEncryptedPdf` in `file_check.ts`).
bool isEncryptedPdf(Uint8List bytes) => latin1.decode(bytes, allowInvalid: true).contains('/Encrypt');

final _pageObject = RegExp(r'/Type\s*/Page(?![A-Za-z])');
final _pagesCount = RegExp(r'/Type\s*/Pages\b[^>]*?/Count\s+(\d+)|/Count\s+(\d+)[^>]*?/Type\s*/Pages\b');
final _linearizedCount = RegExp(r'/Linearized\s[^>]*?/N\s+(\d+)');

/// The PDF's page count, or null when it can't be told without a real parser.
///
/// Reads the uncompressed structure only. A PDF that keeps its page objects in
/// compressed object streams returns null, and the import is allowed to go
/// ahead: this check is for the user's benefit, and an over-long file only
/// costs them a cut-off result.
int? countPdfPages(Uint8List bytes) {
  final text = latin1.decode(bytes, allowInvalid: true);
  final linearized = _linearizedCount.firstMatch(text);
  if (linearized != null) return int.parse(linearized.group(1)!);

  // An incrementally updated file repeats objects, so the largest page-tree
  // count wins over a count of page objects.
  int? treeCount;
  for (final m in _pagesCount.allMatches(text)) {
    final n = int.parse(m.group(1) ?? m.group(2)!);
    if (treeCount == null || n > treeCount) treeCount = n;
  }
  if (treeCount != null) return treeCount;

  final objects = _pageObject.allMatches(text).length;
  return objects > 0 ? objects : null;
}

/// What one provider accepts in a single import request.
class ImportFileLimits {
  const ImportFileLimits({
    required this.maxImages,
    required this.maxPdfPages,
    required this.maxImageBytes,
    required this.maxPdfBytes,
    required this.maxTotalBytes,
  });

  final int maxImages;

  /// Pages across all PDFs in one import, which bounds the output.
  final int maxPdfPages;
  final int maxImageBytes;
  final int maxPdfBytes;

  /// Raw bytes across every file. Files are sent base64-encoded, a third
  /// larger, and the request has to fit the provider's size limit.
  final int maxTotalBytes;
}

/// The hosted path's limits (`ai_import_limits`), which every provider below
/// starts from.
const kDefaultImportFileLimits = ImportFileLimits(
  maxImages: 8,
  maxPdfPages: 10,
  maxImageBytes: 7000000,
  maxPdfBytes: 20000000,
  maxTotalBytes: 24000000,
);

/// Limits by Genkit model namespace (`anthropic`, `openai`, `googleai`).
/// Gemini takes files inline only up to a 20 MB request, base64 included, so
/// it gets less in total.
const kImportFileLimits = <String, ImportFileLimits>{
  'anthropic': kDefaultImportFileLimits,
  'openai': kDefaultImportFileLimits,
  'googleai': ImportFileLimits(
    maxImages: 8,
    maxPdfPages: 10,
    maxImageBytes: 7000000,
    maxPdfBytes: 14000000,
    maxTotalBytes: 14000000,
  ),
};

/// The limits for [modelName] (`anthropic/claude-…`), or the defaults.
ImportFileLimits importFileLimitsFor(String modelName) =>
    kImportFileLimits[modelName.split('/').first] ?? kDefaultImportFileLimits;
