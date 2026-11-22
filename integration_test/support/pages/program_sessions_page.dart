import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nomorex/core/constants/app_constants.dart';

import '../harness.dart';

/// The desktop program editor's sessions (a day split into AM / PM …) and a
/// program run's per-session rows.
class ProgramSessionsPage {
  ProgramSessionsPage(this.tester);

  final WidgetTester tester;

  static Finder addSession(String dayId) => find.byKey(ValueKey('edit_day_add_session_$dayId'));
  static Finder sessionMenu(String sessionId) => find.byKey(ValueKey('edit_session_more_$sessionId'));
  static Finder runSessionRow(String sessionId) => find.byKey(ValueKey('program_session_row_$sessionId'));

  /// A run's session row by its title, "Day 1 · Session 2".
  static Finder runRowTitled(String title) => find.text(title);

  /// Goes straight to [path], as a link would.
  Future<void> _go(String path) async {
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(path);
    await tester.pumpAndSettle();
  }

  Future<void> _tap(Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  /// Opens the one-page editor (the test viewport is desktop width) with
  /// [weekTitle] and its day [dayTitle] expanded.
  Future<void> openDayInEditor(String programId, {required String weekTitle, required String dayTitle}) async {
    await _go(AppConstants.routeProgramEdit(programId));
    final week = find.text(weekTitle);
    await waitFor(tester, week);
    await _tap(week);
    await _tap(find.text(dayTitle));
  }

  /// Adds a session to the open day, and waits for the day to show its
  /// sessions under their own headings.
  Future<void> addSessionTo(String dayId, {required String firstSessionId}) async {
    await _tap(addSession(dayId));
    await waitFor(tester, sessionMenu(firstSessionId));
  }

  Future<void> openRun(String instanceId) async {
    await _go(AppConstants.routeProgramInstanceDetail(instanceId));
  }
}
