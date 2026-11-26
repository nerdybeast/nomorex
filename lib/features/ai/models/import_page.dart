import 'package:flutter/foundation.dart';

import '../utils/import_file_check.dart';

/// One file in an import, ready to read or upload.
class ImportPage {
  const ImportPage({required this.type, required this.bytes, this.name, this.pdfPages});

  final ImportFileType type;
  final Uint8List bytes;

  /// The file's name, when the platform gave one. Shown for PDFs.
  final String? name;

  /// A PDF's page count, or null when it can't be told (and for images).
  final int? pdfPages;
}
