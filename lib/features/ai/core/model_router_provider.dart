import 'package:flutter/foundation.dart';
import 'package:genkit_apple_intelligence/genkit_apple_intelligence.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'ai_settings_provider.dart';
import 'ai_task.dart';
import 'plugins/apple_plugin.dart';

part 'model_router_provider.g.dart';

/// The bridge to Apple's Foundation Models, as a provider so tests can fake it.
@Riverpod(keepAlive: true)
AppleIntelligenceApi appleIntelligence(Ref ref) => AppleIntelligence();

/// Apple Intelligence's status on iOS and macOS, or null on other platforms.
/// Re-read when the app resumes (`AiImportJobAlerts`), since the lifter may
/// have turned Apple Intelligence on in Settings meanwhile.
@Riverpod(keepAlive: true)
Future<AppleModelStatus?> appleModelStatus(Ref ref) async {
  if (!runsAppleIntelligence()) return null;
  try {
    return await ref.watch(appleIntelligenceProvider).status();
  } catch (e) {
    debugPrint('[ai] Apple Intelligence status failed: $e');
    return AppleModelStatus(availability: AppleModelAvailability.unavailable, supportsImages: false, osVersion: '');
  }
}

/// Whether the on-device model can run, or null when this build has no way to
/// ask: Android and the web until Stage 8 (Gemini Nano, Chrome), and while
/// Apple's status loads. Null is not `unsupported`: the device may well have a
/// model the app can't use yet, so the settings screen says nothing rather
/// than "this device can't run one".
@Riverpod(keepAlive: true)
OnDeviceStatus? onDeviceAvailability(Ref ref) {
  final apple = ref.watch(appleModelStatusProvider).value;
  return apple == null ? null : onDeviceStatusFromApple(apple);
}

/// Which model runs [task] right now, or null when nothing can: the feature
/// hides itself then. Also null while the settings are still loading, so a
/// feature appears once they have.
@riverpod
AiRoute? modelForTask(Ref ref, AiTask task) {
  final settings = ref.watch(aiSettingsProvider).value;
  final onDevice = ref.watch(onDeviceAvailabilityProvider);
  return routeTask(task, cloud: settings?.activeCloud, onDevice: onDevice ?? OnDeviceStatus.unsupported);
}
