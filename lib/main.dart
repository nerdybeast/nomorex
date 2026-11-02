import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicenses();
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    publishableKey: const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );

  await SentryFlutter.init(
    (options) {
      options.dsn = const String.fromEnvironment('SENTRY_DSN');
    },
    appRunner: () => runApp(const ProviderScope(child: NomorexApp())),
  );
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
