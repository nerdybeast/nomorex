import 'package:flutter/foundation.dart';

import 'ai_provider.dart';

/// Something the app asks a model to do. Each task decides which models may
/// run it (see [routeTask]).
enum AiTask {
  /// Reading a workout or program out of files. Needs a cloud model: on-device
  /// models misread too many rows (the #183 spike), so it's never routed there.
  import(ModelTier.standard, cloud: true, onDevice: false),

  /// Small editor helpers. On device only: they're conveniences the lifter
  /// didn't ask to pay for, so they never spend the lifter's own key.
  suggestTitle(ModelTier.fast, cloud: false, onDevice: true),
  suggestDescription(ModelTier.fast, cloud: false, onDevice: true),
  suggestExercises(ModelTier.fast, cloud: false, onDevice: true);

  const AiTask(this.tier, {required this.cloud, required this.onDevice});

  /// Which cloud model size the task needs.
  final ModelTier tier;

  /// Whether the lifter's own cloud key may run it.
  final bool cloud;

  /// Whether the on-device model may run it.
  final bool onDevice;
}

/// Model sizes, the Dart counterpart of `MODELS` in
/// `supabase/functions/ai/genkit.ts`.
enum ModelTier {
  /// Cheap and fast: checks and short answers.
  fast,

  /// Real features, such as imports.
  standard,
}

/// The model each provider uses for each tier. The plugins resolve names they
/// don't know, so a newer model needs no plugin bump. Stage 5's benchmark
/// (#187) settles the OpenAI and Gemini picks.
const Map<CloudAiProvider, Map<ModelTier, String>> kCloudModels = {
  CloudAiProvider.anthropic: {ModelTier.fast: 'claude-haiku-5-5', ModelTier.standard: 'claude-sonnet-5-5'},
  CloudAiProvider.openai: {ModelTier.fast: 'gpt-5.4-mini', ModelTier.standard: 'gpt-5.5'},
  // One model for both: it's on Gemini's free tier, which is most lifters' reason to pick
  // Gemini. It must be one the plugin calls through generateContent: other names (the
  // -latest aliases, gemini-3.5-flash-lite) go to Google's Interactions API, which browsers
  // can't reach (no CORS). model_router_test.dart checks this.
  CloudAiProvider.gemini: {ModelTier.fast: 'gemini-3.5-flash', ModelTier.standard: 'gemini-3.5-flash'},
};

/// The Genkit namespace each plugin registers its models under.
const Map<CloudAiProvider, String> kCloudNamespaces = {
  CloudAiProvider.anthropic: 'anthropic',
  CloudAiProvider.openai: 'openai',
  CloudAiProvider.gemini: 'googleai',
};

/// Whether the on-device model can run right now.
enum OnDeviceAvailability {
  ready,

  /// The device can run one, but it isn't downloaded yet (Android and Chrome).
  /// It's several GB, so the lifter starts it from AI assistant.
  downloadable,

  /// The model is downloading (Android and Chrome), or Apple is preparing it.
  downloading,

  /// The device could run it, but the lifter turned it off (Apple
  /// Intelligence switched off in Settings, for example).
  disabled,

  /// No on-device model on this device or platform.
  unsupported,
}

/// What the device offers. [modelName] is the Genkit name of the on-device
/// model, set by the platform plugin (Apple Intelligence, Gemini Nano or
/// Chrome's) when it's [ready].
@immutable
class OnDeviceStatus {
  const OnDeviceStatus(this.availability, {this.modelName, this.downloadProgress});

  static const unsupported = OnDeviceStatus(OnDeviceAvailability.unsupported);

  final OnDeviceAvailability availability;
  final String? modelName;

  /// 0 to 1 while [OnDeviceAvailability.downloading], when the platform says.
  final double? downloadProgress;

  bool get isReady => availability == OnDeviceAvailability.ready && modelName != null;

  @override
  bool operator ==(Object other) =>
      other is OnDeviceStatus &&
      other.availability == availability &&
      other.modelName == modelName &&
      other.downloadProgress == downloadProgress;

  @override
  int get hashCode => Object.hash(availability, modelName, downloadProgress);
}

/// Which model runs a task. [provider] is the id stored with an import
/// (`anthropic`, `openai`, `gemini` or `on_device`).
@immutable
class AiRoute {
  const AiRoute({required this.provider, required this.modelName, this.cloud});

  final String provider;

  /// The full Genkit model name, such as `anthropic/claude-sonnet-5-5`.
  final String modelName;

  /// The cloud provider, or null on device.
  final CloudAiProvider? cloud;

  bool get onDevice => cloud == null;

  static const onDeviceId = 'on_device';

  @override
  bool operator ==(Object other) =>
      other is AiRoute && other.provider == provider && other.modelName == modelName && other.cloud == cloud;

  @override
  int get hashCode => Object.hash(provider, modelName, cloud);

  @override
  String toString() => 'AiRoute($provider, $modelName)';
}

/// The router: which model runs [task], or null when nothing can, in which
/// case the feature hides itself.
///
/// [cloud] is the chosen cloud provider, passed only when its key is saved.
/// The on-device model is preferred where a task allows both, since it's free
/// and keeps everything on the device.
AiRoute? routeTask(AiTask task, {CloudAiProvider? cloud, OnDeviceStatus onDevice = OnDeviceStatus.unsupported}) {
  if (task.onDevice && onDevice.isReady) {
    return AiRoute(provider: AiRoute.onDeviceId, modelName: onDevice.modelName!);
  }
  if (task.cloud && cloud != null) return cloudRoute(cloud, task.tier);
  return null;
}

/// [cloud]'s model for [tier]. Use [routeTask] for features; this is for the
/// settings screen's key check, which isn't a task.
AiRoute cloudRoute(CloudAiProvider cloud, ModelTier tier) => AiRoute(
  provider: cloud.id,
  modelName: '${kCloudNamespaces[cloud]}/${kCloudModels[cloud]![tier]}',
  cloud: cloud,
);
