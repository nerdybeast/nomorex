import 'package:genkit/genkit.dart';

import 'chrome_ai_stub.dart' if (dart.library.js_interop) 'chrome_ai_web.dart';

/// Chrome's built-in AI (Gemini Nano, through the Prompt API's
/// `LanguageModel`) as a Genkit model on the web.
///
/// Our own small binding rather than `genkit_chrome`: that plugin ignores
/// Genkit's output schema (it needs a `responseConstraint` JS object passed
/// through the request config), reads the system prompt only from config, and
/// exposes neither availability nor the download, which here needs a click.
const kChromeAiModel = 'chrome/gemini-nano';

/// `LanguageModel.availability()`.
enum ChromeAiAvailability {
  available,

  /// The browser supports it, but the model (several GB) isn't downloaded:
  /// [ChromeAiApi.download], from a click.
  downloadable,

  downloading,

  /// No Prompt API, or Chrome says this device can't run it.
  unavailable,
}

/// One reply from the model.
class ChromeAiReply {
  const ChromeAiReply(this.text, {this.inputTokens});

  final String text;

  /// The session's context use after the prompt, where Chrome reports it.
  final int? inputTokens;
}

/// A failure from the Prompt API, with the DOMException's name
/// (`QuotaExceededError` for a prompt too long, `NotAllowedError`, …).
class ChromeAiException implements Exception {
  const ChromeAiException(this.name, this.message);

  final String name;
  final String message;

  @override
  String toString() => 'ChromeAiException($name: $message)';
}

/// The calls the model makes, so tests can answer them without a browser.
abstract interface class ChromeAiApi {
  Future<ChromeAiAvailability> availability();

  /// Downloads the model by creating a session, reporting progress from 0 to
  /// 1. Must start from a click: Chrome needs a user gesture to download.
  Future<void> download(void Function(double progress) onProgress);

  /// One prompt in a fresh session. [schema] is passed as the prompt's
  /// `responseConstraint`, Chrome's own structured output.
  Future<ChromeAiReply> prompt({String? system, required String prompt, Map<String, dynamic>? schema});
}

/// The browser's Prompt API, or one that's always unavailable off the web.
ChromeAiApi createChromeAi() => createPlatformChromeAi();

/// Defines Chrome's Gemini Nano on [ai] as [kChromeAiModel]: one turn, no
/// tools, no images. Failures are worded like the cloud providers' so the
/// app's error mapping handles them.
Model defineChromeAiModel(Genkit ai, {required ChromeAiApi api}) => ai.defineModel(
  name: kChromeAiModel,
  info: ModelInfo(
    label: 'Chrome built-in AI',
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
    final system = StringBuffer();
    final prompt = StringBuffer();
    for (final message in req.messages) {
      for (final part in message.content) {
        if (part.isMedia) {
          throw GenkitException('Chrome built-in AI here takes text only.', status: StatusCode.invalidArgument);
        }
        if (part.isText) (message.role == Role.system ? system : prompt).writeln(part.text);
      }
    }
    final ChromeAiReply reply;
    try {
      reply = await api.prompt(
        system: system.isEmpty ? null : system.toString().trim(),
        prompt: prompt.toString().trim(),
        schema: req.output?.schema,
      );
    } on ChromeAiException catch (e) {
      throw genkitExceptionForChrome(e);
    }
    return ModelResponse(
      finishReason: FinishReason.stop,
      message: Message(role: Role.model, content: [TextPart(text: reply.text)]),
      usage: GenerationUsage(inputTokens: reply.inputTokens),
    );
  },
);

/// A caught DOMException, from its `toString()` ("QuotaExceededError: The
/// input is too large."). Anything else is a plain `Error`.
ChromeAiException chromeAiExceptionFrom(String text) {
  final match = RegExp(r'^(?:Error: )?([A-Za-z]+Error): ?(.*)$', dotAll: true).firstMatch(text);
  if (match == null) return ChromeAiException('Error', text);
  return ChromeAiException(match.group(1)!, match.group(2)!);
}

/// A Prompt API failure as Genkit reports a model failure.
GenkitException genkitExceptionForChrome(ChromeAiException e) => switch (e.name) {
  'QuotaExceededError' => GenkitException(
    'The request exceeded the on-device context window: ${e.message}',
    status: StatusCode.invalidArgument,
  ),
  'NotAllowedError' || 'NotSupportedError' || 'InvalidStateError' => GenkitException(
    'Chrome built-in AI is unavailable: ${e.message}',
    status: StatusCode.unavailable,
  ),
  _ => GenkitException('Chrome built-in AI failed: ${e.name}: ${e.message}', status: StatusCode.unknown),
};
