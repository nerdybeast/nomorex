import 'package:flutter/foundation.dart';

import '../core/ai_provider.dart';

/// How the settings screen describes each cloud provider.
extension CloudAiProviderInfo on CloudAiProvider {
  /// The company the lifter's files go to.
  String get company => switch (this) {
    CloudAiProvider.gemini => 'Google',
    CloudAiProvider.anthropic => 'Anthropic',
    CloudAiProvider.openai => 'OpenAI',
  };

  String get summary => switch (this) {
    CloudAiProvider.gemini => 'Google · free key available',
    CloudAiProvider.anthropic => 'Anthropic · billed to your Anthropic account',
    CloudAiProvider.openai => 'OpenAI · billed to your OpenAI account',
  };

  String get getKeyLabel => switch (this) {
    CloudAiProvider.gemini => 'Get a free key from Google AI Studio',
    CloudAiProvider.anthropic => 'Get a key from the Anthropic Console',
    CloudAiProvider.openai => 'Get a key from the OpenAI platform',
  };

  Uri get getKeyUrl => Uri.parse(switch (this) {
    CloudAiProvider.gemini => 'https://aistudio.google.com/apikey',
    CloudAiProvider.anthropic => 'https://console.anthropic.com/settings/keys',
    CloudAiProvider.openai => 'https://platform.openai.com/api-keys',
  });

  /// How the provider's keys start, as a hint in the empty field.
  String get keyHint => switch (this) {
    CloudAiProvider.gemini => 'AIza…',
    CloudAiProvider.anthropic => 'sk-ant-…',
    CloudAiProvider.openai => 'sk-…',
  };
}

/// The name of this platform's on-device model, or null where there's none
/// to name (Linux, Windows).
String? onDeviceModelLabel({bool isWeb = kIsWeb, TargetPlatform? platform}) {
  if (isWeb) return 'Chrome built-in AI';
  return switch (platform ?? defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.macOS => 'Apple Intelligence',
    TargetPlatform.android => 'Gemini Nano',
    _ => null,
  };
}

/// A saved key as the screen shows it: enough to recognize, not to use.
String maskKey(String key) {
  if (key.length <= 12) return '•' * 12;
  return '${key.substring(0, 6)}${'•' * 12}${key.substring(key.length - 4)}';
}
