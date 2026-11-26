import 'dart:convert';
import 'dart:typed_data';

import 'package:genkit/genkit.dart';

import 'catalog.dart';
import 'file_check.dart';
import 'normalize.dart';
import 'prompt.dart';

/// One file to read, in the order the lifter picked it.
class ImportFile {
  const ImportFile(this.bytes, {this.name});

  final Uint8List bytes;

  /// For messages only; the type always comes from [bytes].
  final String? name;
}

/// Why a set of files can't be imported.
enum ImportFileProblem {
  none,
  notAccepted,
  heic,
  tooLarge,
  tooLargeInTotal,
  tooMany,
  mixed,
  encrypted,
  tooManyPages,
}

class ImportFileRejected implements Exception {
  const ImportFileRejected(this.problem, {this.file});

  final ImportFileProblem problem;

  /// The file at fault, when one is.
  final ImportFile? file;

  @override
  String toString() => 'ImportFileRejected(${problem.name}${file?.name == null ? '' : ', ${file!.name}'})';
}

/// The files' verified types, in order. Throws [ImportFileRejected] for
/// anything [limits] or the providers won't take. Reads only the files'
/// leading bytes and markers, never parses them: they're untrusted.
List<ImportFileType> checkImportFiles(List<ImportFile> files, ImportFileLimits limits) {
  if (files.isEmpty) throw const ImportFileRejected(ImportFileProblem.none);
  final types = <ImportFileType>[];
  var total = 0;
  var pages = 0;
  for (final f in files) {
    final type = detectImportFileType(f.bytes);
    if (type == null) {
      throw ImportFileRejected(isHeic(f.bytes) ? ImportFileProblem.heic : ImportFileProblem.notAccepted, file: f);
    }
    final limit = type.isImage ? limits.maxImageBytes : limits.maxPdfBytes;
    if (f.bytes.length > limit) throw ImportFileRejected(ImportFileProblem.tooLarge, file: f);
    total += f.bytes.length;
    if (type == ImportFileType.pdf) {
      if (isEncryptedPdf(f.bytes)) throw ImportFileRejected(ImportFileProblem.encrypted, file: f);
      // A PDF whose pages can't be counted is allowed: an over-long file only
      // costs the lifter a cut-off result.
      pages += countPdfPages(f.bytes) ?? 1;
    }
    types.add(type);
  }
  final pdfs = types.where((t) => t == ImportFileType.pdf).length;
  if (pdfs > 0 && pdfs < types.length) throw const ImportFileRejected(ImportFileProblem.mixed);
  if (pdfs == 0 && types.length > limits.maxImages) throw const ImportFileRejected(ImportFileProblem.tooMany);
  if (pdfs > 0 && pages > limits.maxPdfPages) throw const ImportFileRejected(ImportFileProblem.tooManyPages);
  if (total > limits.maxTotalBytes) throw const ImportFileRejected(ImportFileProblem.tooLargeInTotal);
  return types;
}

/// The files as prompt parts, with a label before each one when there are
/// several. The label makes the order explicit rather than implied by
/// position, which matters when a week continues onto the next page or file.
/// Images are "Page N:"; PDFs are "File N:", because each is a document with
/// its own pages. An import is all images or all PDFs.
List<Part> labelImportFiles(List<ImportFile> files, List<ImportFileType> types) {
  MediaPart media(int i) => MediaPart(
    media: Media(url: 'data:${types[i].contentType};base64,${base64Encode(files[i].bytes)}', contentType: types[i].contentType),
  );
  if (files.length < 2) return [for (var i = 0; i < files.length; i++) media(i)];
  return [
    for (var i = 0; i < files.length; i++) ...[
      TextPart(text: '${types[i] == ImportFileType.pdf ? 'File' : 'Page'} ${i + 1}:'),
      media(i),
    ],
  ];
}

/// The output cap. A dense 10-page program used about 17,600 tokens on the
/// hosted path (Claude Sonnet).
const kImportMaxOutputTokens = 20000;

/// Each plugin's name for the output cap, by model namespace. OpenAI's
/// reasoning models count their reasoning against it, so they get more room.
Map<String, Object?> importConfigFor(String modelName) => switch (modelName.split('/').first) {
  'anthropic' => {'maxTokens': kImportMaxOutputTokens},
  'openai' => {'maxTokens': kImportMaxOutputTokens * 2},
  'googleai' || 'vertexai' => {'maxOutputTokens': kImportMaxOutputTokens},
  _ => {'maxOutputTokens': kImportMaxOutputTokens},
};

/// What one import run produced.
sealed class ImportRunOutcome {
  const ImportRunOutcome({this.usage});

  final GenerationUsage? usage;
}

/// A result to review: store [result] with its [detectedType].
class ImportRunOk extends ImportRunOutcome {
  const ImportRunOk(this.result, this.detectedType, {super.usage});

  final Json result;
  final ImportType detectedType;
}

/// The files have no training content.
class ImportRunNoWorkout extends ImportRunOutcome {
  const ImportRunNoWorkout({super.usage});
}

/// The model's reply wasn't a result.
class ImportRunInvalidOutput extends ImportRunOutcome {
  const ImportRunInvalidOutput({super.usage});
}

/// The reply hit the output cap: too much for one import.
class ImportRunCutOff extends ImportRunOutcome {
  const ImportRunCutOff({super.usage});
}

/// Reads [files] with the model named [modelName] (`anthropic/claude-…`) and
/// normalizes the reply against [catalog].
///
/// Throws [ImportFileRejected] before any model call when the files don't
/// fit the provider. A failed model call is rethrown as the provider's
/// [GenkitException] (Genkit returns it as a failed result rather than
/// throwing), for the caller to turn into a message; [use] adds middleware
/// such as retries.
Future<ImportRunOutcome> runImport(
  Genkit ai, {
  required String modelName,
  required List<ImportFile> files,
  required List<CatalogExercise> catalog,
  ImportType? requestedType,
  List<GenerateMiddlewareRef>? use,
  CancellationToken? cancel,
}) async {
  final types = checkImportFiles(files, importFileLimitsFor(modelName));
  final result = await ai.generate<dynamic, dynamic>(
    model: modelRef(modelName),
    system: kImportSystemPrompt,
    promptParts: [
      ...labelImportFiles(files, types),
      TextPart(text: buildImportUserPrompt(catalogLines(catalog), requestedType)),
    ],
    config: importConfigFor(modelName),
    use: use,
    cancel: cancel,
  );
  return interpretImportReply(result, catalog, requestedType);
}

/// Turns a finished generation into an outcome. Split from [runImport] so a
/// caller that makes the model call itself can still use it.
ImportRunOutcome interpretImportReply(
  GenerateResult<dynamic> result,
  List<CatalogExercise> catalog, [
  ImportType? requestedType,
]) {
  final usage = result.usage;
  switch (result.finishReason) {
    case FinishReason.failed || FinishReason.aborted:
      final cause = result.cause;
      if (cause is GenkitException) throw cause;
      throw GenkitException(
        result.finishMessage ?? 'generation failed',
        status: StatusCode.fromWireName(result.error?.status ?? ''),
        cause: cause,
      );
    case FinishReason.blocked:
      throw GenkitException(result.finishMessage ?? 'the model declined', status: StatusCode.permissionDenied);
    case FinishReason.length:
      return ImportRunCutOff(usage: usage);
    default:
  }
  return switch (normalizeImportResult(parseModelJson(result.text), catalog, requestedType)) {
    NormalizeOk(:final result, :final detectedType) => ImportRunOk(result, detectedType, usage: usage),
    NormalizeNoWorkout() => ImportRunNoWorkout(usage: usage),
    NormalizeInvalid() => ImportRunInvalidOutput(usage: usage),
  };
}
