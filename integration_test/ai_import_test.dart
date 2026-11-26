import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/harness.dart';
import 'support/pages/ai_assistant_page.dart';
import 'support/pages/ai_import_page.dart';
import 'support/pages/shell_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('AI import', () {
    // Against the real local stack, where seed.sql switches imports on. Stops
    // before choosing a file, so it never uploads or calls the model.
    testWidgets('New leads to the notice, then to choosing files', (tester) async {
      await bootSignedIn(tester);
      final shell = ShellPage(tester);
      final importFlow = AiImportPage(tester);
      await shell.waitUntilLoaded();

      await shell.goToWorkouts();
      await importFlow.open();
      if (importFlow.noticeShown) {
        // Declining the notice uploads nothing and leaves the flow; it shows
        // again next time, because nothing was recorded.
        await importFlow.declineNotice();
        expect(AiImportPage.newButton, findsOneWidget, reason: 'back beside the sidebar');
        await importFlow.open();
        expect(importFlow.noticeShown, isTrue);
        await importFlow.acceptNotice();
      }
      await importFlow.expectFileChoices();
      await importFlow.close();

      // Accepted once, so Programs goes straight to the files.
      await shell.goToPrograms();
      await importFlow.open();
      await importFlow.expectFileChoices();
      await importFlow.close();
    });

    // The test user has no key (this suite never saves one), so imports take
    // the hosted path seed.sql switches on; the screen offers the settings
    // for a key of their own. Stops there: nothing is saved or tested.
    testWidgets('import without a key leads to the AI assistant settings', (tester) async {
      await bootSignedIn(tester);
      final shell = ShellPage(tester);
      final importFlow = AiImportPage(tester);
      await shell.waitUntilLoaded();

      await shell.goToPrograms();
      await importFlow.open();
      if (importFlow.noticeShown) await importFlow.acceptNotice();
      await importFlow.expectFileChoices();
      if (importFlow.usingOwnKey) {
        // A key saved on this machine outside the suite: the link isn't
        // offered, and that's the path working as intended.
        await importFlow.close();
        return;
      }
      await importFlow.openOwnKeySettings(AiAssistantPage.imports);
      expect(AiAssistantPage.imports, findsOneWidget);
    });
  });
}
