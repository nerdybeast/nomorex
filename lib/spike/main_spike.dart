// SPIKE (#183) harness. Throwaway: run with
//   flutter run -t lib/spike/main_spike.dart [-d macos|chrome|<device>]
// Optional --dart-define=SPIKE_AUTORUN=ondevice|cloud|storage|all to run without tapping,
// and --dart-define=ANTHROPIC_KEY=… / OPENAI_KEY / GEMINI_KEY to seed keys.
import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, FileMode;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_anthropic/genkit_anthropic.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:genkit_openai/genkit_openai.dart';
import 'package:image/image.dart' as img;
// ignore: depend_on_referenced_packages
import 'package:path_provider/path_provider.dart';
import 'package:schemantic/schemantic.dart';

import 'apple_model.dart';
import 'chrome_plugin_stub.dart' if (dart.library.js_interop) 'chrome_plugin_web.dart';

void main() => runApp(const MaterialApp(home: SpikeScreen()));

const _autorun = String.fromEnvironment('SPIKE_AUTORUN');
const _seedKeys = {
  'anthropic': String.fromEnvironment('ANTHROPIC_KEY'),
  'openai': String.fromEnvironment('OPENAI_KEY'),
  'gemini': String.fromEnvironment('GEMINI_KEY'),
};
const _defaultModels = {'anthropic': 'claude-haiku-5-5', 'openai': 'gpt-5-mini', 'gemini': 'gemini-flash-latest'};

final _retry = retry(maxRetries: 4, initialDelay: const Duration(seconds: 2), maxDelay: const Duration(seconds: 20));

const _storage = FlutterSecureStorage(mOptions: MacOsOptions(usesDataProtectionKeychain: false));

final _extractSchema = <String, Object?>{
  'type': 'object',
  'properties': {
    'title': {'type': 'string'},
    'days': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'title': {'type': 'string'},
          'exercises': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'name': {'type': 'string'},
                'sets': {'type': 'integer'},
                'reps': {'type': 'string'},
                'load': {'type': 'string', 'description': 'As printed, e.g. 75% or RPE 7; empty if blank'},
              },
              'required': ['name', 'sets', 'reps', 'load'],
            },
          },
        },
        'required': ['title', 'exercises'],
      },
    },
  },
  'required': ['title', 'days'],
};

const _extractSystem =
    'You read one page of a strength training program and return it as JSON. '
    'Copy exercise names exactly as printed. sets is a whole number. Copy reps and load as printed; '
    'load is an empty string when the cell is blank. Include every row.';

final _titleSchema = <String, Object?>{
  'type': 'object',
  'properties': {
    'title': {'type': 'string', 'description': 'At most 40 characters'},
  },
  'required': ['title'],
};

// A deliberately awkward schema to find what DynamicGenerationSchema can't express.
final _gapSchema = <String, Object?>{
  'type': 'object',
  r'$defs': {
    'Set': {
      'type': 'object',
      'properties': {
        'reps': {'type': 'integer', 'minimum': 1, 'maximum': 50},
        'percent': {
          'type': ['number', 'null'],
          'minimum': 0,
          'maximum': 200,
        },
      },
      'required': ['reps'],
    },
  },
  'properties': {
    'kind': {
      'type': 'string',
      'enum': ['program', 'workout'],
    },
    'name': {'type': 'string', 'maxLength': 40, 'pattern': '^[A-Z]'},
    'sets': {
      'type': 'array',
      'items': {r'$ref': r'#/$defs/Set'},
      'minItems': 1,
      'maxItems': 5,
    },
    'notes': {
      'anyOf': [
        {'type': 'string'},
        {'type': 'null'},
      ],
    },
    'extra': {'type': 'object', 'additionalProperties': true},
    'when': {'type': 'string', 'format': 'date'},
  },
  'required': ['kind', 'name', 'sets'],
};

class SpikeScreen extends StatefulWidget {
  const SpikeScreen({super.key});
  @override
  State<SpikeScreen> createState() => _SpikeScreenState();
}

class _SpikeScreenState extends State<SpikeScreen> {
  final _log = <String>[];
  final _keys = {for (final p in _defaultModels.keys) p: TextEditingController()};
  final _models = {for (final e in _defaultModels.entries) e.key: TextEditingController(text: e.value)};
  bool _busy = false;
  Uint8List? _page;
  Map<String, Object?>? _expected;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    _page = (await rootBundle.load('assets/spike/dense_page.jpg')).buffer.asUint8List();
    _expected = jsonDecode(await rootBundle.loadString('assets/spike/dense_page_expected.json')) as Map<String, Object?>;
    for (final p in _keys.keys) {
      String? k;
      try {
        k = await _storage.read(key: 'spike_key_$p');
      } catch (e) {
        _say('secure storage read failed: $e');
      }
      if ((k == null || k.isEmpty) && _seedKeys[p]!.isNotEmpty) k = _seedKeys[p];
      _keys[p]!.text = k ?? '';
    }
    _say('platform: ${kIsWeb ? 'web' : defaultTargetPlatform.name}');
    if (_autorun.isNotEmpty) {
      if (_autorun == 'storage' || _autorun == 'all') await _run(_storageTest);
      if (_autorun == 'ondevice' || _autorun == 'all') await _run(_onDeviceSuite);
      if (_autorun == 'cloud' || _autorun == 'all') await _run(_cloudSuite);
      _say('SPIKE_DONE');
    }
  }

  File? _logFile;

  void _say(String s) {
    debugPrint('[spike] $s');
    if (!kIsWeb) {
      unawaited(() async {
        _logFile ??= File('${(await getApplicationDocumentsDirectory()).path}/spike.log');
        await _logFile!.writeAsString('$s\n', mode: FileMode.append, flush: true);
      }());
    }
    if (mounted) setState(() => _log.add(s));
  }

  Future<void> _run(Future<void> Function() f) async {
    setState(() => _busy = true);
    try {
      await f();
    } catch (e, st) {
      _say('ERROR $e\n${st.toString().split('\n').take(4).join('\n')}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Genkit _genkit() {
    String? key(String p) => _keys[p]!.text.trim().isEmpty ? null : _keys[p]!.text.trim();
    return Genkit(
      plugins: [
        if (key('anthropic') != null)
          anthropic(
            apiKey: key('anthropic'),
            headers: kIsWeb ? {'anthropic-dangerous-direct-browser-access': 'true'} : null,
          ),
        if (key('openai') != null) openAI(apiKey: key('openai')),
        if (key('gemini') != null) googleAI(apiKey: key('gemini')),
        if (kIsWeb) ...chromePlugins(),
      ],
    );
  }

  ModelRef<dynamic> _ref(String p) => switch (p) {
    'anthropic' => anthropic.model(_models[p]!.text),
    'openai' => openAI.model(_models[p]!.text),
    _ => googleAI.gemini(_models[p]!.text),
  };

  // ---------- secure storage ----------
  Future<void> _storageTest() async {
    final sw = Stopwatch()..start();
    try {
      await _storage.write(key: 'spike_probe', value: 'sk-test-123');
      final v = await _storage.read(key: 'spike_probe');
      await _storage.delete(key: 'spike_probe');
      _say('secure storage: write/read/delete ${v == 'sk-test-123' ? 'OK' : 'MISMATCH ($v)'} in ${sw.elapsedMilliseconds} ms');
    } catch (e) {
      _say('secure storage FAILED: $e');
    }
  }

  Future<void> _saveKeys() async {
    for (final e in _keys.entries) {
      await _storage.write(key: 'spike_key_${e.key}', value: e.value.text.trim());
    }
    _say('keys saved');
  }

  // ---------- cloud ----------
  Future<void> _cloudSuite() async {
    for (final p in _keys.keys) {
      if (_keys[p]!.text.trim().isEmpty) {
        _say('$p: no key, skipped');
        continue;
      }
      await _cloud(p);
    }
  }

  Future<void> _cloud(String p) async {
    final ai = _genkit();
    final model = _ref(p);
    Future<void> step(String name, Future<GenerateResult<dynamic>> Function() f, [void Function(GenerateResult<dynamic>)? check]) async {
      final sw = Stopwatch()..start();
      try {
        final r = await f().timeout(const Duration(seconds: 90));
        final u = r.usage;
        if (r.finishReason != FinishReason.stop) _say('$p/$name finish=${r.finishReason} msg=${_short('${r.finishMessage}', 600)}');
        _say('$p/$name OK ${sw.elapsedMilliseconds} ms in=${u?.inputTokens} out=${u?.outputTokens}: ${_short(r.text)}');
        check?.call(r);
      } catch (e) {
        _say('$p/$name FAILED ${sw.elapsedMilliseconds} ms: ${_short('$e', 400)}');
      }
    }

    await step('text', () => ai.generate(model: model, use: [_retry], prompt: 'Reply with the single word OK.'));
    await step(
      'json',
      () => ai.generate(
        model: model,
        use: [_retry],
        prompt: 'Suggest a short workout title for: Clean pull 4x3, Front squat 5x3, Romanian deadlift 3x8.',
        outputSchema: SchemanticType.from(jsonSchema: _titleSchema, parse: (j) => j),
      ),
    );
    final small = _resized(1600);
    await step(
      'image',
      () => ai.generate(
        model: model,
        use: [_retry],
        system: _extractSystem,
        promptParts: [
          MediaPart(media: Media(url: 'data:image/jpeg;base64,${base64Encode(small)}', contentType: 'image/jpeg')),
          TextPart(text: 'Read this page.'),
        ],
        outputSchema: SchemanticType.from(jsonSchema: _extractSchema, parse: (j) => j),
      ),
      (r) => _say('$p/image accuracy: ${_score(r.output)}'),
    );
    final pdf = (await rootBundle.load('assets/spike/dense_page.pdf')).buffer.asUint8List();
    await step(
      'pdf',
      () => ai.generate(
        model: model,
        use: [_retry],
        system: _extractSystem,
        promptParts: [
          MediaPart(media: Media(url: 'data:application/pdf;base64,${base64Encode(pdf)}', contentType: 'application/pdf')),
          TextPart(text: 'Read this page.'),
        ],
        outputSchema: SchemanticType.from(jsonSchema: _extractSchema, parse: (j) => j),
      ),
      (r) => _say('$p/pdf accuracy: ${_score(r.output)}'),
    );
  }

  // ---------- on device ----------
  Future<void> _onDeviceSuite() async {
    final status = await onDeviceStatus();
    _say('on-device status: $status');
    if (kIsWeb) {
      await _chromeTest();
      return;
    }
    if (status['state'] != 'available') return;
    final ai = _genkit();
    final apple = defineAppleModel(ai);
    final ref = modelRef(apple.name);

    Future<GenerateResult<dynamic>?> go(String name, Future<GenerateResult<dynamic>> Function() f) async {
      final sw = Stopwatch()..start();
      try {
        final r = await f();
        if (r.text.isEmpty) _say('apple/$name empty: finish=${r.finishReason} msg=${r.finishMessage}');
        _say('apple/$name OK ${sw.elapsedMilliseconds} ms bridge=${_bridgeInfo()}: ${_short(r.text, 300)}');
        return r;
      } catch (e) {
        _say('apple/$name FAILED ${sw.elapsedMilliseconds} ms bridge=${_bridgeInfo()}: ${_short('$e', 400)}');
        return null;
      }
    }

    await go('text', () => ai.generate(model: ref, prompt: 'Reply with the single word OK.'));
    await go(
      'title',
      () => ai.generate(
        model: ref,
        prompt: 'Suggest a short workout title for: Clean pull 4x3, Front squat 5x3, Romanian deadlift 3x8.',
        outputSchema: SchemanticType.from(jsonSchema: _titleSchema, parse: (j) => j),
      ),
    );
    lastAppleResult = null;
    await go(
      'gapSchema',
      () => ai.generate(
        model: ref,
        prompt: 'Make up one example workout with two sets.',
        outputSchema: SchemanticType.from(jsonSchema: _gapSchema, parse: (j) => j),
      ),
    );
    _say('apple/gapSchema gaps: ${lastAppleResult?['schemaGaps']}');
    try {
      final raw = await onDeviceChannel.invokeMapMethod<String, Object?>('generate', {
        'prompt': 'Make up one example workout with two sets.',
        'schema': jsonEncode(_gapSchema),
      });
      _say('apple/gapSchema direct: ${raw?['schemaGaps']} -> ${_short('${raw?['text']}', 300)}');
    } catch (e) {
      _say('apple/gapSchema direct FAILED: ${_short('$e', 500)}');
    }

    // Single photo. "full" = the dense 32-row page; "day1" = a one-workout crop (8 rows).
    const cfg = {'temperature': 0.0, 'maxOutputTokens': 1500};
    for (final crop in ['day1', 'full']) {
      final bytes = _resized(1600, crop: crop);
      final r = await go(
        'photo[$crop]',
        () => ai.generate(
          model: ref,
          system: _extractSystem,
          config: cfg,
          promptParts: [
            MediaPart(media: Media(url: 'data:image/jpeg;base64,${base64Encode(bytes)}', contentType: 'image/jpeg')),
            TextPart(text: 'Read this page.'),
          ],
          outputSchema: SchemanticType.from(jsonSchema: _extractSchema, parse: (j) => j),
        ),
      );
      if (r != null) _say('apple/photo[$crop] accuracy: ${_score(r.output, crop: crop)}');
      for (final method in ['ocr', 'docOcr']) {
        final ocr = await onDeviceChannel.invokeMapMethod<String, Object?>(method, {'image': bytes});
        final text = ocr!['text'] as String;
        _say('$method[$crop] ${ocr['ms']} ms, tables=${ocr['tables']}, ${text.length} chars');
        if (crop == 'full') _say('$method text:\n$text');
        final r = await go(
          '$method[$crop]',
          () => ai.generate(
            model: ref,
            system: _extractSystem,
            config: cfg,
            prompt: 'This is the OCR text of the page, one table row per line, cells separated by |:\n$text',
            outputSchema: SchemanticType.from(jsonSchema: _extractSchema, parse: (j) => j),
          ),
        );
        if (r != null) _say('apple/$method[$crop] accuracy: ${_score(r.output, crop: crop)}');
      }
    }
  }

  Future<void> _chromeTest() async {
    final ai = _genkit();
    final sw = Stopwatch()..start();
    try {
      final r = await ai.generate(
        model: modelRef('chrome/gemini-nano'),
        prompt: 'Suggest a short workout title for: Clean pull 4x3, Front squat 5x3, Romanian deadlift 3x8.',
        outputSchema: SchemanticType.from(jsonSchema: _titleSchema, parse: (j) => j),
      );
      _say('chrome/title OK ${sw.elapsedMilliseconds} ms: ${_short(r.text)}');
    } catch (e) {
      _say('chrome/title FAILED: ${_short('$e', 400)}');
    }
  }

  String _bridgeInfo() {
    final r = lastAppleResult;
    if (r == null) return '-';
    return {for (final k in ['ms', 'inputTokens', 'outputTokens', 'promptTextTokens', 'instructionTokens', 'schemaTokens', 'imageSize']) if (r[k] != null) k: r[k]}.toString();
  }

  // ---------- helpers ----------
  Uint8List _resized(int width, {String crop = 'full'}) {
    var src = img.decodeJpg(_page!)!;
    if (crop == 'day1') src = img.copyCrop(src, x: 0, y: 0, width: src.width, height: (src.height * 0.278).round());
    if (src.width == width && crop == 'full') return _page!;
    return Uint8List.fromList(img.encodeJpg(img.copyResize(src, width: width, interpolation: img.Interpolation.average), quality: 85));
  }

  static String _short(String s, [int n = 160]) {
    final t = s.replaceAll('\n', ' ');
    return t.length <= n ? t : '${t.substring(0, n)}…';
  }

  static String _norm(Object? s) => '$s'.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Fraction of expected exercise rows reproduced exactly (name, sets, reps, load), plus day count.
  String _score(Object? output, {String crop = 'full'}) {
    if (output is! Map) return 'no JSON';
    var expDays = (_expected!['days'] as List).cast<Map<String, Object?>>();
    if (crop == 'day1') expDays = expDays.take(1).toList();
    final gotDays = ((output['days'] as List?) ?? const []).whereType<Map<dynamic, dynamic>>().toList();
    var exact = 0, names = 0, total = 0;
    for (var d = 0; d < expDays.length; d++) {
      final exp = (expDays[d]['exercises'] as List).cast<Map<String, Object?>>();
      final got = d < gotDays.length ? ((gotDays[d]['exercises'] as List?) ?? const []).whereType<Map<dynamic, dynamic>>().toList() : const <Map<dynamic, dynamic>>[];
      for (var i = 0; i < exp.length; i++) {
        total++;
        final g = got.where((x) => _norm(x['name']) == _norm(exp[i]['name'])).firstOrNull;
        if (g == null) continue;
        names++;
        if (_norm(g['sets']) == _norm(exp[i]['sets']) && _norm(g['reps']) == _norm(exp[i]['reps']) && _norm(g['load']) == _norm(exp[i]['load'])) exact++;
      }
    }
    final gotRows = gotDays.fold<int>(0, (n, d) => n + ((d['exercises'] as List?)?.length ?? 0));
    return 'days ${gotDays.length}/${expDays.length}, names $names/$total, exact rows $exact/$total, rows returned $gotRows';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BYOAI spike (#183)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final p in _keys.keys)
            Row(
              children: [
                Expanded(child: TextField(controller: _keys[p], obscureText: true, decoration: InputDecoration(labelText: '$p key'))),
                const SizedBox(width: 8),
                SizedBox(width: 180, child: TextField(controller: _models[p], decoration: const InputDecoration(labelText: 'model'))),
              ],
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(onPressed: _busy ? null : () => _run(_saveKeys), child: const Text('Save keys')),
              FilledButton(onPressed: _busy ? null : () => _run(_storageTest), child: const Text('Secure storage')),
              FilledButton(onPressed: _busy ? null : () => _run(_cloudSuite), child: const Text('Cloud suite')),
              FilledButton(onPressed: _busy ? null : () => _run(_onDeviceSuite), child: const Text('On-device suite')),
              OutlinedButton(onPressed: () => setState(_log.clear), child: const Text('Clear')),
            ],
          ),
          if (_busy) const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
          const Divider(),
          for (final l in _log.reversed) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: SelectableText(l, style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
        ],
      ),
    );
  }
}
