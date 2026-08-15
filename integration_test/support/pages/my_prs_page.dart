import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/shared/widgets/pr_card.dart';

import '../harness.dart';

/// The "MY PRS" tab at `/shell/prs`.
class MyPrsPage {
  MyPrsPage(this.tester);

  final WidgetTester tester;

  static final title = find.text('MY PRS');

  Future<void> waitUntilLoaded() => waitFor(tester, title);

  /// Asserts the authenticated PR query actually resolved.
  ///
  /// Deliberately does not assert the list is empty: file execution order
  /// across the suite isn't guaranteed, so a test that added a PR may already
  /// have run. What matters here is that the screen reached a data state
  /// rather than the error branch.
  Future<void> expectLoadedWithoutError() async {
    await waitUntilLoaded();

    final empty = find.text('No PRs found.');
    final cards = find.byType(PrCard);
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (empty.evaluate().isNotEmpty || cards.evaluate().isNotEmpty) {
        expect(find.textContaining('Failed to load PRs'), findsNothing);
        return;
      }
    }
    fail('My PRs never reached a data state (still loading, or errored)');
  }

  /// Asserts a card for [exerciseName] is present.
  ///
  /// Presence, not count — the suite must stay green on a second run against a
  /// stack that was not freshly reset.
  Future<void> expectPrCard(String exerciseName) async {
    final card = find.widgetWithText(PrCard, exerciseName);
    await waitFor(tester, card);
    expect(card, findsWidgets);
  }
}
