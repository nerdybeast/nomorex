/// Apple Intelligence (Foundation Models) as a Genkit model, on iOS and macOS.
///
/// ```dart
/// final status = await AppleIntelligence().status();
/// if (status.availability == AppleModelAvailability.available) {
///   defineAppleIntelligenceModel(ai, status: status);
///   await ai.generate(model: modelRef(kAppleIntelligenceModel), prompt: '…');
/// }
/// ```
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:genkit/genkit.dart';

import 'src/messages.g.dart';

export 'src/messages.g.dart'
    show AppleGenerateRequest, AppleGenerateResponse, AppleModelAvailability, AppleModelStatus;

/// The model's Genkit name.
const kAppleIntelligenceModel = 'apple/foundation';

/// The reply cap when a request sets none. The model must always have one:
/// an uncapped run in the #183 spike looped for 206 s until it overflowed
/// the context.
const kAppleDefaultMaxResponseTokens = 1024;

/// The calls the model makes, so tests can answer them without a device.
abstract interface class AppleIntelligenceApi {
  Future<AppleModelStatus> status();
  Future<AppleGenerateResponse> generate(AppleGenerateRequest request);
  Future<int?> countTokens(String text);
}

/// The real bridge to Foundation Models.
class AppleIntelligence implements AppleIntelligenceApi {
  AppleIntelligence([AppleIntelligenceHostApi? host]) : _host = host ?? AppleIntelligenceHostApi();

  final AppleIntelligenceHostApi _host;

  /// Whether the model can run here. Never throws: a platform without the
  /// plugin (Android, web, tests) reports [AppleModelAvailability.unsupportedOS].
  @override
  Future<AppleModelStatus> status() async {
    try {
      return await _host.status();
    } on MissingPluginException {
      return AppleModelStatus(availability: AppleModelAvailability.unsupportedOS, supportsImages: false, osVersion: '');
    } on PlatformException catch (e) {
      if (e.code == 'channel-error') {
        return AppleModelStatus(
          availability: AppleModelAvailability.unsupportedOS,
          supportsImages: false,
          osVersion: '',
        );
      }
      rethrow;
    }
  }

  @override
  Future<AppleGenerateResponse> generate(AppleGenerateRequest request) => _host.generate(request);

  /// Tokens [text] takes as a prompt, or null where the OS can't count
  /// (before iOS / macOS 26.4). With `contextSize`, callers can plan a budget.
  @override
  Future<int?> countTokens(String text) => _host.countTokens(text);
}

/// Defines the Apple Intelligence model on [ai] as [kAppleIntelligenceModel].
///
/// [status] decides what the model declares: image input only where the OS
/// takes it (iOS / macOS 27). It takes no tools and one turn: each call is a
/// fresh `LanguageModelSession`.
///
/// Structured output uses Apple's guided generation: the request's JSON
/// schema becomes a `DynamicGenerationSchema`. A schema that can't be
/// translated (a free-form map) is put in the prompt instead, and the reply
/// parsed as JSON.
///
/// Failures follow Genkit's convention and the app's error mapping: a refusal
/// comes back as [FinishReason.blocked]; an overflowing context, a busy model
/// and an unavailable one as [GenkitException]s worded like the cloud
/// providers' (`context window`, `rate limit`, [StatusCode.unavailable]).
Model defineAppleIntelligenceModel(Genkit ai, {required AppleModelStatus status, AppleIntelligenceApi? api}) {
  final bridge = api ?? AppleIntelligence();
  return ai.defineModel(
    name: kAppleIntelligenceModel,
    info: ModelInfo(
      label: 'Apple Intelligence (on device)',
      supports: {
        'multiturn': false,
        'media': status.supportsImages,
        'systemRole': true,
        'tools': false,
        'constrained': 'all',
        'output': ['text', 'json'],
      },
    ),
    fn: (req, ctx) async {
      final request = appleRequestFor(req, status: status);
      AppleGenerateResponse response;
      try {
        try {
          response = await bridge.generate(request);
        } on PlatformException catch (e) {
          if (e.code != 'schemaUnsupported' || request.schemaJson == null) rethrow;
          // Guided generation can't express it: ask for the JSON in words.
          response = await bridge.generate(withSchemaInPrompt(request));
        }
      } on PlatformException catch (e) {
        if (e.code == 'refused') {
          return ModelResponse(
            finishReason: FinishReason.blocked,
            finishMessage: 'Apple Intelligence declined to answer.',
            message: Message(role: Role.model, content: const []),
          );
        }
        throw genkitExceptionFor(e);
      }
      return ModelResponse(
        finishReason: FinishReason.stop,
        message: Message(role: Role.model, content: [TextPart(text: response.text)]),
        usage: GenerationUsage(inputTokens: response.inputTokens, outputTokens: response.outputTokens),
      );
    },
  );
}

/// The bridge request for a Genkit request: system messages become the
/// session's instructions, the rest the prompt, and at most one image.
AppleGenerateRequest appleRequestFor(ModelRequest req, {required AppleModelStatus status}) {
  final instructions = StringBuffer();
  final prompt = StringBuffer();
  Uint8List? image;
  for (final message in req.messages) {
    for (final part in message.content) {
      if (part.isText) {
        (message.role == Role.system ? instructions : prompt).writeln(part.text);
      } else if (part.isMedia) {
        if (!status.supportsImages) {
          throw GenkitException('Image input needs iOS or macOS 27.', status: StatusCode.invalidArgument);
        }
        if (image != null) {
          throw GenkitException('Apple Intelligence takes one image per request.', status: StatusCode.invalidArgument);
        }
        image = _mediaBytes(part.media!.url);
      }
    }
  }
  final config = req.config ?? const {};
  final cap = (config['maxOutputTokens'] ?? config['maxTokens']) as num?;
  final schema = req.output?.schema;
  return AppleGenerateRequest(
    instructions: instructions.isEmpty ? null : instructions.toString().trim(),
    prompt: prompt.toString().trim(),
    schemaJson: schema == null ? null : jsonEncode(schema),
    image: image,
    temperature: (config['temperature'] as num?)?.toDouble(),
    maximumResponseTokens: cap?.toInt() ?? kAppleDefaultMaxResponseTokens,
  );
}

/// [request] with its schema moved into the prompt, for a schema guided
/// generation can't express.
AppleGenerateRequest withSchemaInPrompt(AppleGenerateRequest request) => AppleGenerateRequest(
  instructions: request.instructions,
  prompt:
      '${request.prompt}\n\nAnswer with JSON data only: no code fences and no other text. The data must be '
      'valid against the JSON Schema below. Write the data itself, never the schema or its keywords '
      '("type", "properties"):\n${request.schemaJson}',
  image: request.image,
  temperature: request.temperature,
  maximumResponseTokens: request.maximumResponseTokens,
);

/// A bridge error as Genkit reports a model failure. The wording matches
/// what the app's `aiExceptionFrom` recognizes for the cloud providers.
GenkitException genkitExceptionFor(PlatformException e) {
  final detail = e.message ?? e.code;
  return switch (e.code) {
    'tooLong' => GenkitException(
      'The request exceeded the on-device context window: $detail',
      status: StatusCode.invalidArgument,
    ),
    'rateLimited' => GenkitException('Rate limit reached on device: $detail', status: StatusCode.resourceExhausted),
    'unavailable' || 'unsupported' => GenkitException(
      'Apple Intelligence is unavailable: $detail',
      status: StatusCode.unavailable,
    ),
    'badImage' || 'unsupportedLanguage' || 'schemaUnsupported' => GenkitException(
      detail,
      status: StatusCode.invalidArgument,
    ),
    _ => GenkitException('Apple Intelligence failed: $detail', status: StatusCode.unknown),
  };
}

Uint8List _mediaBytes(String url) {
  if (!url.startsWith('data:')) {
    throw GenkitException('Apple Intelligence takes images as data URLs.', status: StatusCode.invalidArgument);
  }
  return base64Decode(url.substring(url.indexOf(',') + 1));
}
