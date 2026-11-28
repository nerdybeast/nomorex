/// Gemini Nano through the ML Kit GenAI Prompt API, as a Genkit model on
/// Android.
///
/// ```dart
/// final status = await MlKitGenAi().status();
/// if (status.availability == MlKitModelAvailability.available) {
///   defineMlKitGenAiModel(ai, status: status);
///   await ai.generate(model: modelRef(kMlKitGenAiModel), prompt: '…');
/// }
/// ```
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:genkit/genkit.dart';

import 'src/messages.g.dart';

export 'src/messages.g.dart'
    show MlKitGenerateRequest, MlKitGenerateResponse, MlKitModelAvailability, MlKitModelStatus;

/// The model's Genkit name.
const kMlKitGenAiModel = 'mlkit/gemini-nano';

/// The reply cap when a request sets none. Always set, as on Apple.
const kMlKitDefaultMaxOutputTokens = 1024;

/// The calls the model makes, so tests can answer them without a device.
abstract interface class MlKitGenAiApi {
  Future<MlKitModelStatus> status();
  Future<void> startDownload();
  Future<MlKitGenerateResponse> generate(MlKitGenerateRequest request);
}

/// The real bridge to ML Kit.
class MlKitGenAi implements MlKitGenAiApi {
  MlKitGenAi([MlKitGenAiHostApi? host]) : _host = host ?? MlKitGenAiHostApi();

  final MlKitGenAiHostApi _host;

  /// Whether Gemini Nano can run here. Never throws: a platform without the
  /// plugin (iOS, web, tests) reports [MlKitModelAvailability.unavailable].
  @override
  Future<MlKitModelStatus> status() async {
    try {
      return await _host.status();
    } on MissingPluginException {
      return _unavailable;
    } on PlatformException catch (e) {
      if (e.code == 'channel-error') return _unavailable;
      rethrow;
    }
  }

  static final _unavailable = MlKitModelStatus(
    availability: MlKitModelAvailability.unavailable,
    sdkInt: 0,
    deviceModel: '',
  );

  /// Starts the model download, which [status] then reports. It's large, so
  /// only on the lifter's say-so.
  @override
  Future<void> startDownload() => _host.startDownload();

  @override
  Future<MlKitGenerateResponse> generate(MlKitGenerateRequest request) => _host.generate(request);
}

/// Defines Gemini Nano on [ai] as [kMlKitGenAiModel].
///
/// One turn, no tools, no images. ML Kit's structured output is compile-time
/// only (Kotlin `@Generable`), so a request's output schema goes in the prompt
/// and the reply is parsed as JSON. A reply that stops at the cap is
/// [FinishReason.length].
///
/// Failures are worded like the cloud providers' so the app's error mapping
/// handles them: a too-long prompt mentions the context window, a busy model
/// the rate limit, and an unavailable one is [StatusCode.unavailable].
Model defineMlKitGenAiModel(Genkit ai, {required MlKitModelStatus status, MlKitGenAiApi? api}) {
  final bridge = api ?? MlKitGenAi();
  return ai.defineModel(
    name: kMlKitGenAiModel,
    info: ModelInfo(
      label: 'Gemini Nano (on device)',
      supports: {
        'multiturn': false,
        'media': false,
        'systemRole': true,
        'tools': false,
        'constrained': 'all',
        'output': ['text', 'json'],
      },
    ),
    fn: (req, ctx) async {
      final MlKitGenerateResponse response;
      try {
        response = await bridge.generate(mlKitRequestFor(req));
      } on PlatformException catch (e) {
        throw genkitExceptionForMlKit(e);
      }
      return ModelResponse(
        finishReason: response.cutOff ? FinishReason.length : FinishReason.stop,
        message: Message(role: Role.model, content: [TextPart(text: response.text)]),
        usage: GenerationUsage(inputTokens: response.inputTokens),
      );
    },
  );
}

/// The bridge request for a Genkit request: system text first (ML Kit has no
/// system role in every version), then the rest, then the output schema.
MlKitGenerateRequest mlKitRequestFor(ModelRequest req) {
  final instructions = StringBuffer();
  final prompt = StringBuffer();
  for (final message in req.messages) {
    for (final part in message.content) {
      if (part.isMedia) {
        throw GenkitException('Gemini Nano here takes text only.', status: StatusCode.invalidArgument);
      }
      if (part.isText) (message.role == Role.system ? instructions : prompt).writeln(part.text);
    }
  }
  final schema = req.output?.schema;
  final text = [
    if (instructions.isNotEmpty) instructions.toString().trim(),
    prompt.toString().trim(),
    if (schema != null)
      'Answer with JSON data only: no code fences and no other text. The data must be valid against the JSON '
          'Schema below. Write the data itself, never the schema or its keywords ("type", "properties"):\n'
          '${jsonEncode(schema)}',
  ].join('\n\n');
  final config = req.config ?? const {};
  final cap = (config['maxOutputTokens'] ?? config['maxTokens']) as num?;
  return MlKitGenerateRequest(
    prompt: text,
    temperature: (config['temperature'] as num?)?.toDouble(),
    maxOutputTokens: cap?.toInt() ?? kMlKitDefaultMaxOutputTokens,
  );
}

/// A bridge error as Genkit reports a model failure, worded for the app's
/// `aiExceptionFrom`.
GenkitException genkitExceptionForMlKit(PlatformException e) {
  final detail = e.message ?? e.code;
  return switch (e.code) {
    'tooLong' => GenkitException(
      'The request exceeded the on-device context window: $detail',
      status: StatusCode.invalidArgument,
    ),
    'busy' => GenkitException('Rate limit reached on device: $detail', status: StatusCode.resourceExhausted),
    'unavailable' => GenkitException('Gemini Nano is unavailable: $detail', status: StatusCode.unavailable),
    _ => GenkitException('Gemini Nano failed: $detail', status: StatusCode.unknown),
  };
}
