import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness.dart';

/// The AI import flow: the entry point in the sidebar's "New" menu, the
/// one-time notice, and the screen for choosing files. Nothing here picks a
/// file or starts an import, so no model is ever called.
class AiImportPage {
  AiImportPage(this.tester);

  final WidgetTester tester;

  static final newButton = find.byKey(const Key('shell_add_fab'));
  static final entry = find.byKey(const Key('ai_import_entry'));
  static final notice = find.byKey(const Key('ai_import_notice'));
  static final chooseImages = find.byKey(const Key('ai_import_choose_images'));
  static final choosePdf = find.byKey(const Key('ai_import_choose_pdf'));
  static final _noticeOrFiles = find.byWidgetPredicate(
    (w) => w.key == const Key('ai_import_notice') || w.key == const Key('ai_import_choose_images'),
  );

  /// Opens "New", taps the import entry and waits for the screen's own check
  /// to finish. The entry appears once the import limits have loaded.
  Future<void> open() async {
    await waitFor(tester, newButton);
    await tester.tap(newButton);
    await tester.pumpAndSettle();
    await waitFor(tester, entry);
    await tester.tap(entry);
    await waitFor(tester, _noticeOrFiles);
    await tester.pumpAndSettle();
  }

  /// Whether the one-time notice is showing. It only shows until the test
  /// user first accepts it, so a stack that wasn't freshly reset skips it.
  bool get noticeShown => notice.evaluate().isNotEmpty;

  Future<void> declineNotice() async {
    await tester.tap(find.byKey(const Key('ai_import_notice_decline')));
    await waitForAbsent(tester, notice);
    await tester.pumpAndSettle();
  }

  Future<void> acceptNotice() async {
    await tester.tap(find.byKey(const Key('ai_import_notice_accept')));
    await waitFor(tester, chooseImages);
    await tester.pumpAndSettle();
  }

  Future<void> expectFileChoices() async {
    await waitFor(tester, chooseImages);
    expect(choosePdf, findsOneWidget);
    expect(notice, findsNothing);
  }

  Future<void> close() async {
    await tester.tap(find.byTooltip('Back'));
    await waitForAbsent(tester, chooseImages);
    await tester.pumpAndSettle();
  }
}
