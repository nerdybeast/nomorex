import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness.dart';

/// The authenticated `StatefulShellRoute` at `/shell/*`.
///
/// Both desktop targets open a window wider than `kMobileBreakpoint` (600px),
/// so `AppFrame` shows the sidebar. Tab labels below are the sidebar's
/// destination labels, and [goToTab] only looks inside the sidebar.
class ShellPage {
  ShellPage(this.tester);

  final WidgetTester tester;

  /// The sidebar's "New" button (the phone layout's FAB has the same key).
  static final addFab = find.byKey(const Key('shell_add_fab'));
  static final sidebar = find.byKey(const Key('app_sidebar'));

  /// Waits until the shell has replaced the auth screens.
  Future<void> waitUntilLoaded() => waitFor(tester, addFab);

  Future<void> goToTab(String label) async {
    // Scoped to the sidebar: screen titles share these labels (sentence
    // case), so a bare find.text could hit the app bar instead.
    final destination = find.descendant(
      of: sidebar,
      matching: find.text(label),
    );
    await waitFor(tester, destination);
    await tester.tap(destination.first);
    await tester.pumpAndSettle();
  }

  Future<void> goToHome() => goToTab('Home');
  Future<void> goToMyPrs() => goToTab('My PRs');
  Future<void> goToWorkouts() => goToTab('Workouts');
  Future<void> goToPrograms() => goToTab('Programs');
  Future<void> goToCommunity() => goToTab('Community');

  /// Opens the sidebar's "New" menu and picks one of its entries:
  /// "New personal best", "New workout", "New program".
  Future<void> createNew(String entry) async {
    await tester.tap(addFab);
    await tester.pumpAndSettle();

    final tile = find.widgetWithText(MenuItemButton, entry);
    expect(tile, findsOneWidget, reason: 'New menu should offer "$entry"');
    await tester.tap(tile);
    await tester.pumpAndSettle();
  }
}
