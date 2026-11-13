import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../firebase_options.dart';

/// Product analytics: what people use, through Google Analytics for Firebase.
/// Errors and crashes stay in Sentry.
///
/// Everything goes through this interface rather than `FirebaseAnalytics`
/// directly, so widget tests (which never initialize Firebase) and platforms
/// Firebase Analytics doesn't support get [NoopAnalytics]. Calls never throw:
/// a failed analytics call must not fail the action it describes.
abstract interface class AppAnalytics {
  /// Logs [name] (one of [AnalyticsEvents]) with optional [params]. Values
  /// must be `String` or `num`. Never pass names, emails, notes or other
  /// free text a user typed.
  void logEvent(String name, [Map<String, Object>? params]);

  void logLogin();

  /// [screenName] is a route pattern such as `/workouts/:id`, never a filled
  /// in location, so record IDs don't reach analytics.
  void logScreenView(String screenName);

  Future<void> setCollectionEnabled(bool enabled);
}

/// Event names, kept in one place so reports and code agree. GA4 limits
/// names to 40 characters and reserves the `firebase_`, `google_` and `ga_`
/// prefixes.
abstract final class AnalyticsEvents {
  /// Params: `method` = `start` | `repeat` | `community`.
  static const workoutStarted = 'workout_started';

  /// Params: `from_program` = 1 | 0.
  static const workoutFinished = 'workout_finished';

  /// Params: `reps`.
  static const prLogged = 'pr_logged';

  /// Params: `method` = `own` | `community`.
  static const programStarted = 'program_started';

  /// Saving (or saving and starting) someone else's public workout or
  /// program. Params: `content_type` = `workout` | `program`, `started` = 1 | 0.
  static const communityCopy = 'community_copy';

  /// Params: `requested_type` = `auto` | `workout` | `program`, `rerun` = 1 | 0.
  static const aiImportStarted = 'ai_import_started';

  /// Params: `content_type` = `workout` | `program`.
  static const aiImportAccepted = 'ai_import_accepted';
}

/// Firebase Analytics runs on Android, iOS, macOS and web. Linux and Windows
/// desktop (including CI's E2E run) get no Firebase at all.
bool get analyticsPlatformSupported =>
    kIsWeb ||
    switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };

/// Debug and profile builds (`flutter run`, E2E) don't send analytics unless
/// built with `--dart-define=ANALYTICS_DEBUG=true`, which is how to check
/// events in Firebase's DebugView.
const bool analyticsCollectsInThisBuild = kReleaseMode || bool.fromEnvironment('ANALYTICS_DEBUG');

/// Initializes Firebase where Analytics is supported. A failure is reported
/// to Sentry and leaves the app running without analytics.
Future<void> initFirebase() async {
  if (!analyticsPlatformSupported) return;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    // The native SDKs remember this across launches, so a debug build turns
    // collection off before it can log anything automatically. The user's
    // choice is applied once it loads (AnalyticsConsentNotifier).
    if (!analyticsCollectsInThisBuild) {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(false);
    }
  } catch (error, stackTrace) {
    await Sentry.captureException(error, stackTrace: stackTrace);
  }
}

/// [AppAnalytics] when Firebase isn't initialized.
class NoopAnalytics implements AppAnalytics {
  const NoopAnalytics();

  @override
  void logEvent(String name, [Map<String, Object>? params]) {}

  @override
  void logLogin() {}

  @override
  void logScreenView(String screenName) {}

  @override
  Future<void> setCollectionEnabled(bool enabled) async {}
}

class FirebaseAppAnalytics implements AppAnalytics {
  FirebaseAppAnalytics(this._analytics);

  final FirebaseAnalytics _analytics;

  @override
  void logEvent(String name, [Map<String, Object>? params]) =>
      _quietly(_analytics.logEvent(name: name, parameters: params));

  @override
  void logLogin() => _quietly(_analytics.logLogin(loginMethod: 'email'));

  @override
  void logScreenView(String screenName) =>
      _quietly(_analytics.logScreenView(screenName: screenName, screenClass: screenName));

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    try {
      await _analytics.setAnalyticsCollectionEnabled(enabled);
    } catch (e) {
      debugPrint('[analytics] setAnalyticsCollectionEnabled failed: $e');
    }
  }

  static void _quietly(Future<void> call) {
    unawaited(call.catchError((Object e) => debugPrint('[analytics] $e')));
  }
}
