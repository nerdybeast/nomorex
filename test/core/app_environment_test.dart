import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/core/environment/app_environment.dart';

void main() {
  group('AppEnvironment.fromName', () {
    test('nothing defined is local', () {
      expect(AppEnvironment.fromName(''), AppEnvironment.local);
    });

    test('reads each environment by name', () {
      expect(AppEnvironment.fromName('local'), AppEnvironment.local);
      expect(AppEnvironment.fromName('beta'), AppEnvironment.beta);
      expect(AppEnvironment.fromName('production'), AppEnvironment.production);
    });

    test('an unknown name throws instead of quietly becoming local', () {
      expect(() => AppEnvironment.fromName('test'), throwsArgumentError);
      expect(() => AppEnvironment.fromName('prod'), throwsArgumentError);
      expect(() => AppEnvironment.fromName('Beta'), throwsArgumentError);
    });
  });

  group('collectsTelemetry', () {
    bool collects(AppEnvironment environment, {required bool release, bool debugOptIn = false}) =>
        collectsTelemetry(environment: environment, release: release, debugOptIn: debugOptIn);

    test('release builds collect on beta and production, never on local', () {
      expect(collects(AppEnvironment.beta, release: true), isTrue);
      expect(collects(AppEnvironment.production, release: true), isTrue);
      expect(collects(AppEnvironment.local, release: true), isFalse);
    });

    test('debug builds do not collect, whatever the environment', () {
      for (final environment in AppEnvironment.values) {
        expect(collects(environment, release: false), isFalse, reason: environment.name);
      }
    });

    test('a debug build collects only when it opts in', () {
      for (final environment in AppEnvironment.values) {
        expect(collects(environment, release: false, debugOptIn: true), isTrue, reason: environment.name);
      }
    });

    test('the opt-in does not change release builds', () {
      expect(collects(AppEnvironment.local, release: true, debugOptIn: true), isFalse);
    });
  });

  group('telemetryEnvironmentFor', () {
    test('a release build reports as its own environment', () {
      expect(
        telemetryEnvironmentFor(environment: AppEnvironment.beta, release: true),
        AppEnvironment.beta,
      );
      expect(
        telemetryEnvironmentFor(environment: AppEnvironment.production, release: true),
        AppEnvironment.production,
      );
    });

    test('a debug build that opted in reports as local, even against beta', () {
      expect(
        telemetryEnvironmentFor(environment: AppEnvironment.beta, release: false),
        AppEnvironment.local,
      );
    });
  });

  test('widget tests run as local with no telemetry', () {
    expect(AppEnvironment.current, AppEnvironment.local);
    expect(telemetryEnabledInThisBuild, isFalse);
    expect(telemetryEnvironmentInThisBuild, AppEnvironment.local);
  });
}
