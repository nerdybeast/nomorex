import 'chrome_ai.dart';

ChromeAiApi createPlatformChromeAi() => const UnavailableChromeAi();

/// Off the web: there's no browser to ask.
class UnavailableChromeAi implements ChromeAiApi {
  const UnavailableChromeAi();

  @override
  Future<ChromeAiAvailability> availability() async => ChromeAiAvailability.unavailable;

  @override
  Future<void> download(void Function(double progress) onProgress) async =>
      throw const ChromeAiException('NotSupportedError', 'Only in a browser');

  @override
  Future<ChromeAiReply> prompt({String? system, required String prompt, Map<String, dynamic>? schema}) async =>
      throw const ChromeAiException('NotSupportedError', 'Only in a browser');
}
