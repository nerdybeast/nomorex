import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness.dart';

/// The Community tab and its read-only workout/program previews, including the
/// "Save to my …" / "Start …" actions that copy public content into the
/// viewer's own library.
class CommunityPage {
  CommunityPage(this.tester);

  final WidgetTester tester;

  static final programsTab = find.byKey(const Key('community_tab_programs'));
  static final workoutsTab = find.byKey(const Key('community_tab_workouts'));
  static final search = find.byKey(const Key('community_search'));

  static final saveWorkout = find.byKey(const Key('community_workout_save'));
  static final startWorkout = find.byKey(const Key('community_workout_start'));
  static final saveProgram = find.byKey(const Key('community_program_save'));
  static final startProgram = find.byKey(const Key('community_program_start'));

  Future<void> waitUntilLoaded() => waitFor(tester, search);

  /// Filters the [tab] by [title] and opens the matching card.
  Future<void> _open(Finder tab, String title) async {
    await waitUntilLoaded();
    await tester.tap(tab);
    await tester.pumpAndSettle();
    await tester.enterText(search, title);
    await tester.pump();
    // The search field also renders [title]; the card is what we want.
    final card = find.widgetWithText(Card, title);
    await waitFor(tester, card);
    await tester.tap(card.first);
    await tester.pumpAndSettle();
  }

  Future<void> openWorkout(String title) async {
    await _open(workoutsTab, title);
    await waitFor(tester, saveWorkout);
  }

  Future<void> openProgram(String title) async {
    await _open(programsTab, title);
    await waitFor(tester, saveProgram);
  }

  Future<void> _tap(Finder button) async {
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pump();
  }

  /// Saves the open workout and waits for the confirmation SnackBar.
  Future<void> saveOpenWorkout() async {
    await _tap(saveWorkout);
    await waitFor(tester, find.text('Saved to your workouts'));
  }

  /// Starts the open workout; lands in the copy's in-progress session.
  Future<void> startOpenWorkout() async {
    await _tap(startWorkout);
    await waitFor(tester, find.text('Pause'));
  }

  /// Saves the open program and waits for the confirmation SnackBar.
  Future<void> saveOpenProgram() async {
    await _tap(saveProgram);
    await waitFor(tester, find.text('Saved to your programs'));
  }

  /// Starts the open program from today (the dialog's default date).
  Future<void> startOpenProgram() async {
    await _tap(startProgram);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Start'));
    await tester.pump();
  }

  /// Taps the SnackBar's "View" action to open the copy just saved.
  Future<void> viewSavedCopy() async {
    final view = find.text('View');
    await waitFor(tester, view);
    await tester.tap(view);
    await tester.pumpAndSettle();
  }
}
