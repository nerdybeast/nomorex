import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:import_pipeline/import_pipeline.dart' show importFileLimitsFor;
import '../core/ai_provider.dart';
import '../core/ai_settings_provider.dart';
import '../core/ai_task.dart';
import '../core/model_router_provider.dart';
import '../models/ai_import_limits.dart';
import 'ai_import_intake_provider.dart';

part 'ai_import_path_provider.g.dart';

/// How an import would run right now.
enum ImportPath {
  /// In the app, with the lifter's own key (`modelForTask(AiTask.import)`).
  local,

  /// Through the hosted alpha (the `ai` function), while it's switched on.
  hosted,

  /// Neither, but a key can be added: the import screen offers the settings.
  needsKey,

  /// Nothing can run, and no key can be stored on this device (Linux without
  /// a keyring) while the hosted alpha is off: imports are hidden.
  unavailable,
}

/// The import path, or null while the settings or the hosted switch are still
/// loading. A key wins over the hosted alpha: it costs the project nothing,
/// and the lifter chose it.
@riverpod
ImportPath? aiImportPath(Ref ref) {
  if (ref.watch(modelForTaskProvider(AiTask.import)) != null) return ImportPath.local;
  final settings = ref.watch(aiSettingsProvider);
  final limits = ref.watch(aiImportLimitsProvider);
  if (!settings.hasValue && !settings.hasError) return null;
  if (!limits.hasValue && !limits.hasError) return null;
  // A failed read of the switch counts as off, as it always has.
  if (limits.value?.enabled ?? false) return ImportPath.hosted;
  final canStoreKeys = settings.value?.keyStorageAvailable ?? false;
  return canStoreKeys ? ImportPath.needsKey : ImportPath.unavailable;
}

/// Whether the import entry points show: the "New" menus, Home's getting
/// started and Programs' "Add a program". False while loading, so nothing
/// appears and then vanishes.
@riverpod
bool aiImportAvailable(Ref ref) {
  final path = ref.watch(aiImportPathProvider);
  return path != null && path != ImportPath.unavailable;
}

/// The file limits for an import on [path]: the provider's own for a local
/// run (`importFileLimitsFor`), else the hosted row's.
@riverpod
Future<AiImportLimits> aiImportIntakeLimits(Ref ref) async {
  final route = ref.watch(modelForTaskProvider(AiTask.import));
  if (route != null) {
    final l = importFileLimitsFor(route.modelName);
    return AiImportLimits(
      maxImages: l.maxImages,
      maxPdfPages: l.maxPdfPages,
      maxImageBytes: l.maxImageBytes,
      maxPdfBytes: l.maxPdfBytes,
      maxTotalBytes: l.maxTotalBytes,
    );
  }
  return ref.watch(aiImportLimitsProvider.future);
}

/// The providers whose one-time notice this device has shown and the lifter
/// accepted. Stored on the device, like the key: it's about sending files
/// from here to that provider, and is separate from the hosted alpha's
/// `ai_import_consents`.
@Riverpod(keepAlive: true)
class AiImportNoticeNotifier extends _$AiImportNoticeNotifier {
  static String _prefKey(CloudAiProvider p) => 'ai_import_notice_${p.id}';

  @override
  Future<Set<CloudAiProvider>> build() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        for (final p in CloudAiProvider.values)
          if (prefs.getBool(_prefKey(p)) ?? false) p,
      };
    } catch (_) {
      return const {};
    }
  }

  Future<void> accept(CloudAiProvider provider) async {
    final current = await future;
    state = AsyncData({...current, provider});
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey(provider), true);
    } catch (_) {
      // Not saved: the notice shows again next launch, which is harmless.
    }
  }
}
