import 'dart:ui' show Size;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/app.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Seeded local test user, dedicated to this suite. Created directly in
/// `auth.users` by `supabase/seed.sql`, already email-confirmed, with no data
/// of its own. The suite writes to it (copies, a PR, the AI consent), so it
/// never signs in as a@a.com, whose data people use by hand.
const kTestEmail = 'e2e@e2e.com';
const kTestPassword = '123456';

/// `Supabase.initialize` throws if called twice, and every test in a file runs
/// against the same process, so guard it.
bool _supabaseReady = false;

Future<void> _ensureSupabase() async {
  if (_supabaseReady) return;

  // Same compile-time constants as lib/main.dart. These are baked in by
  // --dart-define at build time; unset values silently become empty strings,
  // which would otherwise surface as a confusing connection error much later.
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  if (url.isEmpty || key.isEmpty) {
    fail(
      'SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY are empty. Run the suite via '
      './scripts/e2e.sh, or pass --dart-define-from-file=.env.local.json.',
    );
  }

  await Supabase.initialize(
    url: url,
    publishableKey: key,
    // Disable session persistence for the suite.
    //
    // With the default SharedPreferences storage, a session written by a
    // previous run is restored from disk *asynchronously* during initialize.
    // That races the sign-out below: `currentSession` reads null, the sign-out
    // is skipped, the restore then lands and the router redirects past the
    // landing screen — so the first test of a run fails while every later one
    // passes. Keeping sessions in memory only makes each run self-contained.
    authOptions: const FlutterAuthClientOptions(
      localStorage: EmptyLocalStorage(),
    ),
  );
  _supabaseReady = true;
}

/// Boots the real app in a signed-out state and pumps it to a settled frame.
///
/// The sign-out is load-bearing: `supabase_flutter` restores a persisted
/// session from disk during `initialize`, and `RouterNotifier.redirect` reads
/// `auth.currentSession` directly (lib/app.dart), so a leftover session from a
/// previous run would redirect straight past the landing screen.
Future<void> bootSignedOut(WidgetTester tester) async {
  _pinViewport(tester);
  await _ensureSupabase();
  if (Supabase.instance.client.auth.currentSession != null) {
    await Supabase.instance.client.auth.signOut();
  }
  await tester.pumpWidget(const ProviderScope(child: NomorexApp()));
  await tester.pumpAndSettle();
}

/// Boots the real app already signed in as [kTestEmail].
///
/// Signs in through the auth API before the app starts, so the router lands
/// straight in the shell. Only the auth test goes through the landing and login
/// screens (`bootSignedOut`, then `LoginPage.signIn`); everything else would
/// just repeat those screens' time on every test.
Future<void> bootSignedIn(WidgetTester tester) async {
  _pinViewport(tester);
  await _ensureSupabase();
  final auth = Supabase.instance.client.auth;
  if (auth.currentSession != null) await auth.signOut();
  await auth.signInWithPassword(email: kTestEmail, password: kTestPassword);
  await tester.pumpWidget(const ProviderScope(child: NomorexApp()));
  await tester.pumpAndSettle();
}

/// Every test renders at the same size, whatever window the OS gave the app:
/// 1280x800 at 1x is wide enough for the expanded sidebar (the phone layout
/// below 600px has none) and tall enough that a screen's controls are built
/// without scrolling to them. Linux under xvfb and a macOS window restored at
/// some saved size would otherwise lay the app out differently.
void _pinViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Polls until [finder] matches, pumping frames as it goes.
///
/// Preferred over a bare `pumpAndSettle` for anything gated on a Supabase
/// round-trip: `pumpAndSettle` waits for *all* animation to stop, so a spinner
/// that is still on screen keeps it blocked, and it gives a far less useful
/// message when the thing you wanted never arrives.
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out after $timeout waiting for: $finder');
}

/// Polls until [finder] matches nothing — e.g. waiting for a screen to pop.
Future<void> waitForAbsent(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isEmpty) return;
  }
  fail('Timed out after $timeout waiting for absence of: $finder');
}
