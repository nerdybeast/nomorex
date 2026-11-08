import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

Future<void> main() async {
  // Binding, Sentry and the app all start inside one zone. Calling
  // WidgetsFlutterBinding.ensureInitialized() outside it, before
  // SentryFlutter.init, causes a "Zone mismatch" on web.
  Sentry.runZonedGuarded(() async {
    SentryWidgetsFlutterBinding.ensureInitialized();
    _registerFontLicenses();

    await SentryFlutter.init(
      (options) {
        options.dsn = const String.fromEnvironment('SENTRY_DSN');
        // Only the deploy workflows pass 'production'; local runs, PR builds
        // and E2E stay 'development'.
        options.environment =
            const String.fromEnvironment('SENTRY_ENVIRONMENT', defaultValue: 'development');
        // nomorex@<version>+<build>, matching the release the deploy
        // workflows upload debug symbols and source maps under.
        const release = String.fromEnvironment('SENTRY_RELEASE');
        if (release.isNotEmpty) options.release = release;
        const dist = String.fromEnvironment('SENTRY_DIST');
        if (dist.isNotEmpty) options.dist = dist;
        // Opt-in since sentry_flutter 10; keeps the iOS/macOS capture of
        // failed native HTTP requests that v9 enabled by default.
        options.captureNativeFailedRequests = true;
      },
      appRunner: () async {
        // Inside the app runner so a failed Supabase init is reported.
        await Supabase.initialize(
          url: const String.fromEnvironment('SUPABASE_URL'),
          publishableKey: const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
        );
        runApp(const ProviderScope(child: NomorexApp()));
      },
    );
  }, (error, stackTrace) {
    // Already reported to Sentry by runZonedGuarded; nothing else to do.
  });
}

/// The bundled fonts (see pubspec.yaml) are SIL OFL licensed; list their
/// licenses alongside the packages' own.
void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (package, path) in const [
      ('Inter', 'assets/fonts/Inter/OFL.txt'),
      ('JetBrains Mono', 'assets/fonts/JetBrainsMono/OFL.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([package], await rootBundle.loadString(path));
    }
  });
}
