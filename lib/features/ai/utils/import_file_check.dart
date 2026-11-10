import 'dart:convert';
import 'dart:typed_data';

/// The four file types an import accepts. Mirrors `detectFileType` in
/// `supabase/functions/ai/ai_import/file_check.ts`, which is the real check:
/// everything here only spares the user a failed upload.
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

/// The longest edge sent to the model. Claude reads images at up to 2576 px
/// on the long edge, so anything larger costs upload time for nothing.
const kImportImageMaxEdge = 2576;

/// JPEG quality for images the app re-encodes. High enough to keep pencil
/// handwriting legible.
const kImportJpegQuality = 85;

/// Mirrors `MAX_TOTAL_BYTES` in `supabase/functions/ai/flows/start_ai_import.ts`.
/// Not in `ai_import_limits` because it protects the edge function's memory,
/// not a product limit.
const kImportMaxTotalBytes = 24000000;

bool _startsWith(Uint8List bytes, List<int> signature, [int offset = 0]) {
  if (bytes.length < offset + signature.length) return false;
  for (var i = 0; i < signature.length; i++) {
    if (bytes[offset + i] != signature[i]) return false;
  }
  return true;
}

/// The file's real type from its leading bytes, or null if it isn't one of
/// the accepted types. The name and declared type are never consulted.
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

/// Whether the bytes are a HEIC/HEIF photo, which the server can't accept and
/// the app can only convert where the platform picker does it.
bool isHeic(Uint8List bytes) {
  // An ISO-BMFF "ftyp" box at offset 4, then a HEIF brand.
  if (!_startsWith(bytes, const [0x66, 0x74, 0x79, 0x70], 4) || bytes.length < 12) return false;
  final brand = latin1.decode(bytes.sublist(8, 12));
  return const {'heic', 'heix', 'hevc', 'hevx', 'heim', 'heis', 'mif1', 'msf1'}.contains(brand);
}

/// Whether a PDF is password protected, the same marker search the server
/// does (`isEncryptedPdf` in `file_check.ts`).
bool isEncryptedPdf(Uint8List bytes) => latin1.decode(bytes, allowInvalid: true).contains('/Encrypt');

final _pageObject = RegExp(r'/Type\s*/Page(?![A-Za-z])');
final _pagesCount = RegExp(r'/Type\s*/Pages\b[^>]*?/Count\s+(\d+)|/Count\s+(\d+)[^>]*?/Type\s*/Pages\b');
final _linearizedCount = RegExp(r'/Linearized\s[^>]*?/N\s+(\d+)');

/// The PDF's page count, or null when it can't be told without a real parser.
///
/// Reads the uncompressed structure only. A PDF that keeps its page objects in
/// compressed object streams returns null, and the import is allowed to go
/// ahead: this check is for the user's benefit, and an over-long file only
/// costs them a timeout.
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

/// A size in decimal megabytes, the unit the limits are written in:
/// 7000000 is "7 MB", 20400000 is "20.4 MB". Never rounded to a whole number,
/// so a file just over a limit doesn't read as equal to it.
String formatMegabytes(int bytes) {
  final mb = bytes / 1000000;
  if (mb == mb.roundToDouble()) return '${mb.round()} MB';
  return '${mb.toStringAsFixed(1)} MB';
}
