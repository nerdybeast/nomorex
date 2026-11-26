// The byte sniffing (file types, HEIC, encrypted PDFs, page counts) lives in
// the import pipeline package, shared with the server-free import path.
export 'package:import_pipeline/import_pipeline.dart'
    show ImportFileType, countPdfPages, detectImportFileType, isEncryptedPdf, isHeic;

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

/// A size in decimal megabytes, the unit the limits are written in:
/// 7000000 is "7 MB", 20400000 is "20.4 MB". Never rounded to a whole number,
/// so a file just over a limit doesn't read as equal to it.
String formatMegabytes(int bytes) {
  final mb = bytes / 1000000;
  if (mb == mb.roundToDouble()) return '${mb.round()} MB';
  return '${mb.toStringAsFixed(1)} MB';
}
