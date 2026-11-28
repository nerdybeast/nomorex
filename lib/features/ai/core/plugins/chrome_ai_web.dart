import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'chrome_ai.dart';

ChromeAiApi createPlatformChromeAi() => BrowserChromeAi();

@JS('LanguageModel')
external _LanguageModelFactory? get _languageModel;

extension type _LanguageModelFactory._(JSObject _) implements JSObject {
  external JSPromise<JSString> availability([JSObject? options]);
  external JSPromise<_LanguageModelSession> create([JSObject? options]);
}

extension type _LanguageModelSession._(JSObject _) implements JSObject {
  external JSPromise<JSString> prompt(String input, [JSObject? options]);
  external void destroy();
}

/// The Prompt API in this browser. Every call names the languages, which
/// Chrome wants (and warns about otherwise), the same way in `availability()`
/// and `create()`, since availability depends on the options.
class BrowserChromeAi implements ChromeAiApi {
  static JSObject _options({String? system, JSFunction? monitor}) {
    final languages = [
      {
        'type': 'text',
        'languages': ['en'],
      },
    ];
    final options = <String, Object?>{'expectedInputs': languages, 'expectedOutputs': languages}.jsify()! as JSObject;
    if (system != null) {
      options['initialPrompts'] = [
        {'role': 'system', 'content': system},
      ].jsify();
    }
    if (monitor != null) options['monitor'] = monitor;
    return options;
  }

  @override
  Future<ChromeAiAvailability> availability() async {
    final api = _languageModel;
    if (api == null) return ChromeAiAvailability.unavailable;
    try {
      final value = (await api.availability(_options()).toDart).toDart;
      return switch (value) {
        'available' => ChromeAiAvailability.available,
        'downloadable' => ChromeAiAvailability.downloadable,
        'downloading' => ChromeAiAvailability.downloading,
        _ => ChromeAiAvailability.unavailable,
      };
    } catch (_) {
      return ChromeAiAvailability.unavailable;
    }
  }

  @override
  Future<void> download(void Function(double progress) onProgress) async {
    final api = _require();
    void onMonitor(JSObject monitor) {
      void onEvent(JSObject event) {
        final loaded = (event['loaded'] as JSNumber?)?.toDartDouble ?? 0;
        final total = (event['total'] as JSNumber?)?.toDartDouble;
        // The spec reports a fraction; older Chrome builds sent bytes and a total.
        onProgress(total != null && total > 1 ? loaded / total : loaded);
      }

      monitor.callMethod('addEventListener'.toJS, 'downloadprogress'.toJS, onEvent.toJS);
    }

    final session = await _guard(() => api.create(_options(monitor: onMonitor.toJS)).toDart);
    session.destroy();
  }

  @override
  Future<ChromeAiReply> prompt({String? system, required String prompt, Map<String, dynamic>? schema}) async {
    final api = _require();
    final session = await _guard(() => api.create(_options(system: system)).toDart);
    try {
      final options = schema == null ? null : ({'responseConstraint': schema}.jsify()! as JSObject);
      final text = await _guard(() => session.prompt(prompt, options).toDart);
      // `inputUsage` in current Chrome, `contextUsage` before it.
      final usage = (session['inputUsage'] ?? session['contextUsage']) as JSNumber?;
      return ChromeAiReply(text.toDart, inputTokens: usage?.toDartDouble.round());
    } finally {
      session.destroy();
    }
  }

  _LanguageModelFactory _require() =>
      _languageModel ?? (throw const ChromeAiException('NotSupportedError', 'This browser has no Prompt API'));

  /// Turns a rejected promise's DOMException into a [ChromeAiException].
  /// Its `toString()` is "Name: message" with both web compilers, which an
  /// `is JSObject` check on the caught value isn't.
  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } catch (e) {
      throw chromeAiExceptionFrom('$e');
    }
  }
}
