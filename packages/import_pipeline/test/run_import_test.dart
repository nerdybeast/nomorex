import 'dart:convert';
import 'dart:typed_data';

import 'package:genkit/genkit.dart';
import 'package:import_pipeline/import_pipeline.dart';
import 'package:test/test.dart';

final jpeg = ImportFile(Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3]), name: 'page-1.jpg');
final png = ImportFile(Uint8List.fromList([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0]), name: 'page-2.png');
ImportFile pdf(String body, [String name = 'week.pdf']) =>
    ImportFile(Uint8List.fromList(latin1.encode('%PDF-1.7\n$body')), name: name);

const catalog = [CatalogExercise(id: 'squat', name: 'Back Squat', isPredefined: true)];

const reply = '''```json
{"type": "workout", "title": "Heavy day", "weeks": [{"days": [{"exercises": [
  {"name": "Back Squat", "prescriptions": [{"sets": 5, "reps": 5, "percent": 75}]}
]}]}]}
```''';

/// A Genkit with one fake model; [respond] answers each call.
(Genkit, List<ModelRequest>) fakeAi(Future<ModelResponse> Function(ModelRequest) respond) {
  final ai = Genkit(promptDir: null, isDevEnv: false);
  final requests = <ModelRequest>[];
  ai.defineModel(
    name: 'anthropic/fake',
    fn: (req, ctx) {
      requests.add(req);
      return respond(req);
    },
  );
  return (ai, requests);
}

ModelResponse answer(String text, [FinishReason reason = FinishReason.stop]) => ModelResponse(
  finishReason: reason,
  message: Message(role: Role.model, content: [TextPart(text: text)]),
  usage: GenerationUsage(inputTokens: 100, outputTokens: 50),
);

Future<ImportRunOutcome> run(Genkit ai, {List<ImportFile>? files, ImportType? type}) =>
    runImport(ai, modelName: 'anthropic/fake', files: files ?? [jpeg], catalog: catalog, requestedType: type);

void main() {
  group('checkImportFiles', () {
    test('accepts images, or PDFs, in order', () {
      expect(checkImportFiles([jpeg, png], kDefaultImportFileLimits), [ImportFileType.jpeg, ImportFileType.png]);
      expect(checkImportFiles([pdf('/Type /Page')], kDefaultImportFileLimits), [ImportFileType.pdf]);
    });

    Matcher rejects(ImportFileProblem p) =>
        throwsA(isA<ImportFileRejected>().having((e) => e.problem, 'problem', p));

    test('refuses what no provider takes', () {
      expect(() => checkImportFiles([], kDefaultImportFileLimits), rejects(ImportFileProblem.none));
      expect(
        () => checkImportFiles([ImportFile(Uint8List.fromList(utf8.encode('<svg>')))], kDefaultImportFileLimits),
        rejects(ImportFileProblem.notAccepted),
      );
      final heic = ImportFile(Uint8List.fromList([0, 0, 0, 24, ...latin1.encode('ftypheic')]));
      expect(() => checkImportFiles([heic], kDefaultImportFileLimits), rejects(ImportFileProblem.heic));
      expect(() => checkImportFiles([jpeg, pdf('')], kDefaultImportFileLimits), rejects(ImportFileProblem.mixed));
      expect(
        () => checkImportFiles([pdf('trailer << /Encrypt 5 0 R >>')], kDefaultImportFileLimits),
        rejects(ImportFileProblem.encrypted),
      );
    });

    test('applies the provider limits', () {
      const tight = ImportFileLimits(
        maxImages: 1,
        maxPdfPages: 2,
        maxImageBytes: 8,
        maxPdfBytes: 1000,
        maxTotalBytes: 12,
      );
      expect(() => checkImportFiles([jpeg, jpeg], tight), rejects(ImportFileProblem.tooMany));
      expect(() => checkImportFiles([png], tight), rejects(ImportFileProblem.tooLarge));
      expect(
        () => checkImportFiles([pdf('<< /Type /Pages /Count 3 >>')], tight),
        rejects(ImportFileProblem.tooManyPages),
      );
      expect(
        () => checkImportFiles([pdf('a'), pdf('b')], const ImportFileLimits(
          maxImages: 8,
          maxPdfPages: 10,
          maxImageBytes: 100,
          maxPdfBytes: 100,
          maxTotalBytes: 12,
        )),
        rejects(ImportFileProblem.tooLargeInTotal),
      );
    });
  });

  test('labels several files and keeps a single one bare', () {
    final one = labelImportFiles([jpeg], [ImportFileType.jpeg]);
    expect(one.single, isA<MediaPart>());
    final pages = labelImportFiles([jpeg, png], [ImportFileType.jpeg, ImportFileType.png]);
    expect(pages.whereType<TextPart>().map((p) => p.text), ['Page 1:', 'Page 2:']);
    final files = labelImportFiles([pdf('a'), pdf('b')], [ImportFileType.pdf, ImportFileType.pdf]);
    expect(files.whereType<TextPart>().map((p) => p.text), ['File 1:', 'File 2:']);
    final media = (files[1] as MediaPart).media;
    expect(media.contentType, 'application/pdf');
    expect(media.url, startsWith('data:application/pdf;base64,'));
  });

  test("sets each provider's own output cap", () {
    expect(importConfigFor('anthropic/claude-sonnet-5-5'), {'maxTokens': kImportMaxOutputTokens});
    expect(importConfigFor('openai/gpt-5.5'), {'maxTokens': kImportMaxOutputTokens * 2});
    expect(importConfigFor('googleai/gemini-flash-latest'), {'maxOutputTokens': kImportMaxOutputTokens});
  });

  test('sends the system prompt, the files and the catalog, and normalizes the reply', () async {
    final (ai, requests) = fakeAi((req) async => answer(reply));
    final out = await run(ai, files: [jpeg, png], type: ImportType.workout);

    expect(out, isA<ImportRunOk>());
    final ok = out as ImportRunOk;
    expect(ok.detectedType, ImportType.workout);
    expect(ok.result['title'], 'Heavy day');
    expect(ok.usage?.outputTokens, 50);

    final req = requests.single;
    final system = req.messages.firstWhere((m) => m.role == Role.system);
    expect(system.content.single.text, kImportSystemPrompt);
    final user = req.messages.firstWhere((m) => m.role == Role.user).content;
    expect(user.where((p) => p.isMedia).length, 2);
    expect(user.last.text, contains('Back Squat'));
    expect(user.last.text, contains('this file is a workout'));
    expect(req.config, {'maxTokens': kImportMaxOutputTokens});
  });

  test('no training content, an unreadable reply and a cut-off one are outcomes, not errors', () async {
    expect(await run(fakeAi((_) async => answer('{"type": "none"}')).$1), isA<ImportRunNoWorkout>());
    expect(await run(fakeAi((_) async => answer('Sorry, I cannot.')).$1), isA<ImportRunInvalidOutput>());
    expect(await run(fakeAi((_) async => answer('{"weeks": [', FinishReason.length)).$1), isA<ImportRunCutOff>());
  });

  test("a failed model call is rethrown as the provider's exception", () async {
    final (ai, _) = fakeAi((_) async => throw GenkitException('bad key', status: StatusCode.unauthenticated));
    await expectLater(
      run(ai),
      throwsA(isA<GenkitException>().having((e) => e.status, 'status', StatusCode.unauthenticated)),
    );
  });

  test('bad files are refused before any model call', () async {
    final (ai, requests) = fakeAi((_) async => answer(reply));
    await expectLater(run(ai, files: [jpeg, pdf('')]), throwsA(isA<ImportFileRejected>()));
    expect(requests, isEmpty);
  });
}
