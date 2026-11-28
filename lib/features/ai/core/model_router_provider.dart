import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genkit_apple_intelligence/genkit_apple_intelligence.dart';
import 'package:genkit_mlkit_genai/genkit_mlkit_genai.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'ai_settings_provider.dart';
import 'ai_task.dart';
import 'plugins/apple_plugin.dart';
import 'plugins/chrome_ai.dart';
import 'plugins/on_device_platforms.dart';

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

/// The bridge to ML Kit's Gemini Nano, as a provider so tests can fake it.
@Riverpod(keepAlive: true)
MlKitGenAiApi mlKitGenAi(Ref ref) => MlKitGenAi();

/// Gemini Nano's status in the Android app, or null on other platforms. While
/// it's downloading it's re-read every few seconds, which is how the settings
/// screen's progress bar moves and how the model appears once it's done.
@Riverpod(keepAlive: true)
Future<MlKitModelStatus?> mlKitModelStatus(Ref ref) async {
  if (!runsMlKitGenAi()) return null;
  MlKitModelStatus status;
  try {
    status = await ref.watch(mlKitGenAiProvider).status();
  } catch (e) {
    debugPrint('[ai] Gemini Nano status failed: $e');
    status = MlKitModelStatus(availability: MlKitModelAvailability.unavailable, sdkInt: 0, deviceModel: '');
  }
  if (status.availability == MlKitModelAvailability.downloading) _recheckIn(ref, const Duration(seconds: 2));
  return status;
}

/// The browser's Prompt API, as a provider so tests can fake it.
@Riverpod(keepAlive: true)
ChromeAiApi chromeAi(Ref ref) => createChromeAi();

/// Chrome's built-in AI availability on the web, or null in the apps. Re-read
/// every few seconds while Chrome downloads the model.
@Riverpod(keepAlive: true)
Future<ChromeAiAvailability?> chromeAiAvailability(Ref ref) async {
  if (!kIsWeb) return null;
  final availability = await ref.watch(chromeAiProvider).availability();
  if (availability == ChromeAiAvailability.downloading) _recheckIn(ref, const Duration(seconds: 5));
  return availability;
}

void _recheckIn(Ref ref, Duration delay) {
  final timer = Timer(delay, ref.invalidateSelf);
  ref.onDispose(timer.cancel);
}

/// The on-device model download the lifter started from AI assistant: running,
/// how far along (Chrome reports it only to the page that started it), and why
/// it failed if it did.
@immutable
class OnDeviceDownload {
  const OnDeviceDownload({this.running = false, this.progress, this.error});

  final bool running;
  final double? progress;
  final String? error;
}

/// Starts the on-device model download. On Android ML Kit runs it and
/// [mlKitModelStatusProvider] follows it; on the web Chrome downloads while the
/// session is created, which needs the click that started it.
@Riverpod(keepAlive: true)
class OnDeviceDownloadNotifier extends _$OnDeviceDownloadNotifier {
  @override
  OnDeviceDownload build() => const OnDeviceDownload();

  Future<void> start() async {
    if (state.running) return;
    state = const OnDeviceDownload(running: true);
    try {
      // Whichever platform answered with a status is the one to download for.
      if (ref.read(mlKitModelStatusProvider).value != null) {
        await ref.read(mlKitGenAiProvider).startDownload();
        ref.invalidate(mlKitModelStatusProvider);
        state = const OnDeviceDownload();
      } else if (ref.read(chromeAiAvailabilityProvider).value != null) {
        await ref
            .read(chromeAiProvider)
            .download((progress) => state = OnDeviceDownload(running: true, progress: progress));
        state = const OnDeviceDownload();
        ref.invalidate(chromeAiAvailabilityProvider);
      } else {
        state = const OnDeviceDownload();
      }
    } catch (e) {
      debugPrint('[ai] on-device model download failed: $e');
      state = const OnDeviceDownload(error: "The download didn't finish. Check your connection and space, then try again.");
      ref.invalidate(mlKitModelStatusProvider);
      ref.invalidate(chromeAiAvailabilityProvider);
    }
  }
}

/// Re-reads every on-device status: on app resume (`AiImportJobAlerts`), since
/// Apple Intelligence can be turned on in Settings, and a download can finish,
/// while the app is away.
void refreshOnDeviceStatus(WidgetRef ref) {
  ref.invalidate(appleModelStatusProvider);
  ref.invalidate(mlKitModelStatusProvider);
  ref.invalidate(chromeAiAvailabilityProvider);
}

/// Whether the on-device model can run here, from whichever platform this is:
/// Apple Intelligence (iOS, macOS), Gemini Nano (Android) or Chrome's built-in
/// AI (web). Null where there's none to ask (Linux, Windows) and while the
/// status loads. Null is not `unsupported`: the settings screen says nothing
/// rather than "this device can't run one".
@Riverpod(keepAlive: true)
OnDeviceStatus? onDeviceAvailability(Ref ref) {
  if (ref.watch(appleModelStatusProvider).value case final apple?) return onDeviceStatusFromApple(apple);
  if (ref.watch(mlKitModelStatusProvider).value case final mlKit?) {
    final status = onDeviceStatusFromMlKit(mlKit);
    // Starting a download shows at once, before ML Kit reports it.
    if (status.availability == OnDeviceAvailability.downloadable && ref.watch(onDeviceDownloadProvider).running) {
      return const OnDeviceStatus(OnDeviceAvailability.downloading);
    }
    return status;
  }
  if (ref.watch(chromeAiAvailabilityProvider).value case final chrome?) {
    final download = ref.watch(onDeviceDownloadProvider);
    if (download.running) return OnDeviceStatus(OnDeviceAvailability.downloading, downloadProgress: download.progress);
    return onDeviceStatusFromChrome(chrome);
  }
  return null;
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
