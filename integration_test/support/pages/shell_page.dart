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

  /// The sidebar's "New" button (the phone bar's New item has the same key).
  static final newButton = find.byKey(const Key('shell_new'));
  static final sidebar = find.byKey(const Key('app_sidebar'));

  /// Waits until the shell has replaced the auth screens.
  Future<void> waitUntilLoaded() => waitFor(tester, newButton);

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
  Future<void> goToMyPrs() => goToTraining('prs');
  Future<void> goToWorkouts() => goToTraining('workouts');
  Future<void> goToPrograms() => goToTraining('programs');
  Future<void> goToCommunity() => goToTab('Community');

  /// Opens Training, then one of its views: 'programs', 'workouts' or 'prs'.
  /// Training reopens the view used last, so the view is always tapped.
  Future<void> goToTraining(String view) async {
    await goToTab('Training');
    final segment = find.byKey(Key('training_view_$view'));
    await waitFor(tester, segment);
    await tester.tap(segment);
    await tester.pumpAndSettle();
  }

  /// Opens the sidebar's "New" menu and picks one of its entries:
  /// "New personal best", "New workout", "New program".
  Future<void> createNew(String entry) async {
    await tester.tap(newButton);
    await tester.pumpAndSettle();

    final tile = find.widgetWithText(MenuItemButton, entry);
    expect(tile, findsOneWidget, reason: 'New menu should offer "$entry"');
    await tester.tap(tile);
    await tester.pumpAndSettle();
  }
}
