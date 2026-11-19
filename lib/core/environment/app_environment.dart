import 'package:flutter/foundation.dart';

/// Which environment this build belongs to. Every external service the app
/// talks to (Supabase, Sentry, Firebase) is chosen per environment, so this is
/// the one value they all derive from.
///
/// - [local]: developer machines, cloud agent sessions and CI builds. Sends no
///   telemetry.
/// - [beta]: everything deployed today (TestFlight, GitHub Pages).
/// - [production]: reserved for the official store and website launch.
///
/// Set at compile time with `--dart-define=APP_ENV=local|beta|production`
/// (the define files carry it). Unset means [local].
enum AppEnvironment {
  local,
  beta,
  production;

  /// The environment this build was compiled for.
  static final AppEnvironment current = fromName(const String.fromEnvironment('APP_ENV'));

  /// Reads an `APP_ENV` value. Empty (nothing defined) is [local]; anything
  /// that isn't a known name throws, because a typo in a deploy would
  /// otherwise quietly turn that build's telemetry off.
  static AppEnvironment fromName(String name) {
    if (name.isEmpty) return local;
    for (final environment in values) {
      if (environment.name == name) return environment;
    }
    throw ArgumentError.value(name, 'APP_ENV', 'expected one of ${values.map((e) => e.name).join(', ')}');
  }
}

/// Guards against building one environment's code with another's settings:
/// the Android flavor (`--flavor`) and `APP_ENV` must agree, or the app would
/// carry one environment's application id and Firebase config but talk to
/// another's backend. [flavor] is Flutter's `appFlavor`, `null` where there is
/// no flavor (web, desktop, a build without `--flavor`), and then there's
/// nothing to compare.
void assertFlavorMatchesEnvironment(String? flavor, AppEnvironment environment) {
  if (flavor == null || flavor == environment.name) return;
  throw StateError(
    'This build was made with --flavor $flavor but APP_ENV=${environment.name}. '
    'Use the define file for the same environment, e.g. '
    '--flavor $flavor --dart-define-from-file=.env.$flavor.json.',
  );
}

/// Opt-in for debug and profile builds (`flutter run`, E2E): collect telemetry
/// anyway, e.g. to watch events in Firebase's DebugView. Build with
/// `--dart-define=TELEMETRY_DEBUG=true`.
const bool telemetryDebugOptIn = bool.fromEnvironment('TELEMETRY_DEBUG');

/// Whether a build sends telemetry (Sentry events and analytics).
///
/// A release build sends it unless it is [AppEnvironment.local]. A debug or
/// profile build never does, whatever its environment, unless [debugOptIn]:
/// pointing `flutter run` at the beta backend must not put a developer's
/// half-finished code into beta's error and usage data.
bool collectsTelemetry({
  required AppEnvironment environment,
  required bool release,
  required bool debugOptIn,
}) => release ? environment != AppEnvironment.local : debugOptIn;

/// The environment telemetry from this build is tagged with: the build's own
/// for a release build, and [AppEnvironment.local] for a debug or profile
/// build that opted in, so those events stay apart from real beta traffic.
AppEnvironment telemetryEnvironmentFor({required AppEnvironment environment, required bool release}) =>
    release ? environment : AppEnvironment.local;

/// [collectsTelemetry] for this build.
final bool telemetryEnabledInThisBuild = collectsTelemetry(
  environment: AppEnvironment.current,
  release: kReleaseMode,
  debugOptIn: telemetryDebugOptIn,
);

/// [telemetryEnvironmentFor] for this build.
final AppEnvironment telemetryEnvironmentInThisBuild = telemetryEnvironmentFor(
  environment: AppEnvironment.current,
  release: kReleaseMode,
);
