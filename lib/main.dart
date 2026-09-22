import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    publishableKey: const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );

  await SentryFlutter.init(
    (options) {
      options.dsn =
          'https://6ea4146311980ffaab6d5deaab8222db@o4512127760596992.ingest.us.sentry.io/4512127767150592';
    },
    appRunner: () => runApp(const ProviderScope(child: NomorexApp())),
  );
}
