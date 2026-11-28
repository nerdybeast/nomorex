import 'package:flutter/foundation.dart';
import 'package:genkit_mlkit_genai/genkit_mlkit_genai.dart';

import '../ai_task.dart';
import 'chrome_ai.dart';

/// Whether this platform has Gemini Nano through ML Kit to ask about: the
/// Android app.
bool runsMlKitGenAi({bool isWeb = kIsWeb, TargetPlatform? platform}) =>
    !isWeb && (platform ?? defaultTargetPlatform) == TargetPlatform.android;

/// What the router and the settings screen make of ML Kit's status. While a
/// download this app started runs, its bytes give the progress.
OnDeviceStatus onDeviceStatusFromMlKit(MlKitModelStatus status) => switch (status.availability) {
  MlKitModelAvailability.available => const OnDeviceStatus(OnDeviceAvailability.ready, modelName: kMlKitGenAiModel),
  MlKitModelAvailability.downloadable => const OnDeviceStatus(OnDeviceAvailability.downloadable),
  MlKitModelAvailability.downloading => OnDeviceStatus(
    OnDeviceAvailability.downloading,
    downloadProgress: switch ((status.bytesDownloaded, status.bytesToDownload)) {
      (final done?, final total?) when total > 0 => (done / total).clamp(0, 1).toDouble(),
      _ => null,
    },
  ),
  MlKitModelAvailability.unavailable => OnDeviceStatus.unsupported,
};

/// What the router and the settings screen make of Chrome's availability.
/// [progress] is this page's own download, which Chrome reports only to the
/// page that started it.
OnDeviceStatus onDeviceStatusFromChrome(ChromeAiAvailability availability, {double? progress}) =>
    switch (availability) {
      ChromeAiAvailability.available => const OnDeviceStatus(OnDeviceAvailability.ready, modelName: kChromeAiModel),
      ChromeAiAvailability.downloadable => const OnDeviceStatus(OnDeviceAvailability.downloadable),
      ChromeAiAvailability.downloading => OnDeviceStatus(
        OnDeviceAvailability.downloading,
        downloadProgress: progress,
      ),
      ChromeAiAvailability.unavailable => OnDeviceStatus.unsupported,
    };
