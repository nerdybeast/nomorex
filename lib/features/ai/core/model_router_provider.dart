import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'ai_settings_provider.dart';
import 'ai_task.dart';

part 'model_router_provider.g.dart';

/// Whether the on-device model can run, or null when this build has no way to
/// ask: null everywhere until the Apple Intelligence (Stage 7) and Gemini Nano
/// / Chrome (Stage 8) plugins report here. Null is not `unsupported`: the
/// device may well have a model the app can't use yet, so the settings screen
/// says nothing rather than "this device can't run one".
@Riverpod(keepAlive: true)
OnDeviceStatus? onDeviceAvailability(Ref ref) => null;

/// Which model runs [task] right now, or null when nothing can: the feature
/// hides itself then. Also null while the settings are still loading, so a
/// feature appears once they have.
@riverpod
AiRoute? modelForTask(Ref ref, AiTask task) {
  final settings = ref.watch(aiSettingsProvider).value;
  final onDevice = ref.watch(onDeviceAvailabilityProvider);
  return routeTask(task, cloud: settings?.activeCloud, onDevice: onDevice ?? OnDeviceStatus.unsupported);
}
