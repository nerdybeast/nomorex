import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness.dart';

/// The authenticated `StatefulShellRoute` at `/shell/*`.
///
/// Both desktop targets open a window wider than `kMobileBreakpoint` (600px),
/// so `AppShell` renders its `NavigationRail` branch. Tab labels below are the
/// rail destination labels; the mobile `BottomAppBar` branch uses the same
/// strings, so these finders would still work if the window were narrow.
class ShellPage {
  ShellPage(this.tester);

  final WidgetTester tester;

  static final addFab = find.byKey(const Key('shell_add_fab'));

  /// Waits until the shell has replaced the auth screens.
  Future<void> waitUntilLoaded() => waitFor(tester, addFab);

  Future<void> goToTab(String label) async {
    final destination = find.text(label);
    await waitFor(tester, destination);
    await tester.tap(destination.first);
    await tester.pumpAndSettle();
  }

  Future<void> goToHome() => goToTab('Home');
  Future<void> goToMyPrs() => goToTab('My PRs');
  Future<void> goToWorkouts() => goToTab('Workouts');
  Future<void> goToPrograms() => goToTab('Programs');

  /// Opens the FAB bottom sheet and picks one of its three entries:
  /// "New Personal Best", "New Workout", "New Program".
  Future<void> createNew(String entry) async {
    await tester.tap(addFab);
    await tester.pumpAndSettle();

    final tile = find.widgetWithText(ListTile, entry);
    expect(tile, findsOneWidget, reason: 'FAB sheet should offer "$entry"');
    await tester.tap(tile);
    await tester.pumpAndSettle();
  }
}
