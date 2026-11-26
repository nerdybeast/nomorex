// Runs files through the import pipeline with a real provider and scores the
// result against an answer key. See benchmark/README.md.
//
//   ANTHROPIC_API_KEY=... dart run tool/import_bench.dart --provider anthropic benchmark/dense_page.pdf
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_anthropic/genkit_anthropic.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:genkit_openai/genkit_openai.dart';
import 'package:import_pipeline/import_pipeline.dart';
import 'package:import_pipeline/src/benchmark.dart';

/// The model imports use in the app (`kCloudModels`' standard tier in
/// `lib/features/ai/core/ai_task.dart`). Keep them in step.
const _defaults = {
  'anthropic': ('ANTHROPIC_API_KEY', 'anthropic/claude-sonnet-5-5'),
  'openai': ('OPENAI_API_KEY', 'openai/gpt-5.5'),
  'gemini': ('GEMINI_API_KEY', 'googleai/gemini-flash-latest'),
};

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('provider', allowed: _defaults.keys, mandatory: true)
    ..addOption('model', help: 'Model id without the namespace, such as claude-haiku-5-5.')
    ..addOption('expected', help: 'Answer key. Defaults to the first file with .expected.json.')
    ..addOption('catalog', defaultsTo: 'benchmark/catalog.json')
    ..addOption('type', allowed: ['workout', 'program'])
    ..addOption('out', help: 'Save the last run\'s normalized result here.')
    ..addOption('runs', defaultsTo: '1')
    ..addFlag('help', abbr: 'h', negatable: false);
  final ArgResults opts;
  try {
    opts = parser.parse(args);
  } on FormatException catch (e) {
    _fail('${e.message}\n\n${parser.usage}');
  }
  if (opts.flag('help') || opts.rest.isEmpty) {
    stdout.writeln('dart run tool/import_bench.dart --provider <p> <file> [<file> ...]\n\n${parser.usage}');
    exit(opts.flag('help') ? 0 : 64);
  }

  final provider = opts.option('provider')!;
  final (keyVar, defaultModel) = _defaults[provider]!;
  final key = Platform.environment[keyVar] ?? (provider == 'gemini' ? Platform.environment['GOOGLE_API_KEY'] : null);
  if (key == null || key.isEmpty) _fail('Set $keyVar to your own $provider key.');
  final namespace = defaultModel.split('/').first;
  final modelName = opts.option('model') == null ? defaultModel : '$namespace/${opts.option('model')}';

  final files = [for (final path in opts.rest) ImportFile(File(path).readAsBytesSync(), name: path)];
  final catalog = [
    for (final row in (jsonDecode(File(opts.option('catalog')!).readAsStringSync()) as List).cast<Map<String, dynamic>>())
      CatalogExercise.fromJson(row),
  ];
  final expectedPath = opts.option('expected') ?? opts.rest.first.replaceFirst(RegExp(r'\.[^./]+$'), '.expected.json');
  final expected = File(expectedPath).existsSync()
      ? readAnswerKey(jsonDecode(File(expectedPath).readAsStringSync()) as Map<String, dynamic>)
      : null;
  if (expected == null) stdout.writeln('No answer key at $expectedPath: reporting the run only.');

  final ai = Genkit(
    plugins: [
      switch (provider) {
        'anthropic' => anthropic(apiKey: key),
        'openai' => openAI(apiKey: key),
        _ => googleAI(apiKey: key),
      },
    ],
    promptDir: null,
    isDevEnv: false,
  );

  final runs = int.tryParse(opts.option('runs')!) ?? 1;
  stdout.writeln('$modelName · ${files.length} file(s) · ${catalog.length} catalog exercises · $runs run(s)\n');
  Json? last;
  for (var run = 1; run <= runs; run++) {
    final watch = Stopwatch()..start();
    try {
      final outcome = await runImport(
        ai,
        modelName: modelName,
        files: files,
        catalog: catalog,
        requestedType: ImportType.fromName(opts.option('type')),
        use: [retry(maxRetries: 2, statuses: const [StatusCode.unavailable, StatusCode.internal])],
      );
      final seconds = (watch.elapsedMilliseconds / 1000).toStringAsFixed(1);
      final usage = outcome.usage;
      final tokens = '${usage?.inputTokens ?? '?'} in / ${usage?.outputTokens ?? '?'} out';
      switch (outcome) {
        case ImportRunOk(:final result, :final detectedType):
          last = result;
          final flags = result['flags'] as Json;
          final flagged = [
            for (final e in flags.entries)
              if (e.value == true) e.key,
          ];
          final score = expected == null ? null : BenchScore(expected, resultRows(result));
          stdout.writeln(
            'Run $run: ${score == null ? 'ok' : '${score.exact}/${score.total} exact rows'} · '
            '${detectedType.name} · ${seconds}s · $tokens'
            '${flagged.isEmpty ? '' : ' · flags: ${flagged.join(', ')}'}',
          );
          for (final miss in score?.misses ?? const <String>[]) {
            stdout.writeln('  $miss');
          }
        case ImportRunNoWorkout():
          stdout.writeln('Run $run: no workout found · ${seconds}s · $tokens');
        case ImportRunInvalidOutput():
          stdout.writeln('Run $run: the reply was not a result · ${seconds}s · $tokens');
        case ImportRunCutOff():
          stdout.writeln('Run $run: cut off at the output cap · ${seconds}s · $tokens');
      }
    } on ImportFileRejected catch (e) {
      _fail('The files were refused before any call: ${e.problem.name}${e.file == null ? '' : ' (${e.file!.name})'}');
    } on GenkitException catch (e) {
      stdout.writeln('Run $run: failed after ${watch.elapsedMilliseconds} ms: ${e.status.wireName} ${e.message}');
    }
  }

  final out = opts.option('out');
  if (out != null && last != null) {
    File(out).writeAsStringSync(const JsonEncoder.withIndent(' ').convert(last));
    stdout.writeln('\nSaved the result to $out');
  }
  await ai.shutdown();
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(64);
}
