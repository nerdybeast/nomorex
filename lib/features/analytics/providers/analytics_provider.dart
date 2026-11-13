import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../analytics.dart';

part 'analytics_provider.g.dart';

/// The app's analytics sink. [NoopAnalytics] unless Firebase was initialized
/// (see `initFirebase()`), which keeps widget tests and Linux/Windows
/// desktop off Firebase without any override.
@Riverpod(keepAlive: true)
AppAnalytics analytics(Ref ref) {
  if (!analyticsPlatformSupported) return const NoopAnalytics();
  try {
    if (Firebase.apps.isEmpty) return const NoopAnalytics();
  } catch (_) {
    return const NoopAnalytics();
  }
  return FirebaseAppAnalytics(FirebaseAnalytics.instance);
}

/// Whether the user allows usage analytics: on unless they turn it off in
/// Profile. Saved on the device, like the sidebar state, since collection is
/// a setting of the analytics SDK on this device rather than of the account.
///
/// The choice is applied once it has loaded, never from the default, so a
/// user who opted out isn't briefly collected on launch. The native SDKs
/// also remember the last value across launches. `NomorexApp` watches this
/// so it loads at startup.
@Riverpod(keepAlive: true)
class AnalyticsConsentNotifier extends _$AnalyticsConsentNotifier {
  static const _key = 'analytics_enabled';

  /// Set once the user toggles, so a slow first load can't undo it.
  bool _touched = false;

  @override
  bool build() {
    _load();
    return true;
  }

  Future<void> _load() async {
    bool enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled = prefs.getBool(_key) ?? true;
    } catch (_) {
      // No storage (or a widget test): the default stands.
      enabled = true;
    }
    if (!ref.mounted || _touched) return;
    state = enabled;
    await _apply(enabled);
  }

  Future<void> setEnabled(bool enabled) async {
    _touched = true;
    state = enabled;
    await _apply(enabled);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, enabled);
    } catch (_) {
      // Not saved; it still applies until the app restarts.
    }
  }

  Future<void> _apply(bool enabled) =>
      ref.read(analyticsProvider).setCollectionEnabled(enabled && analyticsCollectsInThisBuild);
}
