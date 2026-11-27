import 'package:flutter/foundation.dart';
import 'package:genkit_apple_intelligence/genkit_apple_intelligence.dart';

import '../ai_task.dart';

/// Whether this platform has Apple Intelligence to ask about: iOS and macOS
/// apps, not the web.
bool runsAppleIntelligence({bool isWeb = kIsWeb, TargetPlatform? platform}) =>
    !isWeb && const {TargetPlatform.iOS, TargetPlatform.macOS}.contains(platform ?? defaultTargetPlatform);

/// What the router and the settings screen make of Apple's availability.
/// "Model not ready" is Apple downloading or preparing it, which the screen
/// shows as downloading.
OnDeviceStatus onDeviceStatusFromApple(AppleModelStatus status) => switch (status.availability) {
  AppleModelAvailability.available => const OnDeviceStatus(
    OnDeviceAvailability.ready,
    modelName: kAppleIntelligenceModel,
  ),
  AppleModelAvailability.appleIntelligenceNotEnabled => const OnDeviceStatus(OnDeviceAvailability.disabled),
  AppleModelAvailability.modelNotReady => const OnDeviceStatus(OnDeviceAvailability.downloading),
  AppleModelAvailability.deviceNotEligible ||
  AppleModelAvailability.unsupportedOS ||
  AppleModelAvailability.unavailable => OnDeviceStatus.unsupported,
};
