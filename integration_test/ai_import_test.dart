import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/harness.dart';
import 'support/pages/ai_import_page.dart';
import 'support/pages/shell_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('AI import', () {
    // Against the real local stack, where seed.sql switches imports on. Stops
    // before choosing a file, so it never uploads or calls the model.
    testWidgets('Workouts and Programs lead to the notice, then to choosing files', (tester) async {
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
        expect(AiImportPage.entry, findsOneWidget, reason: 'back on Workouts');
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
  });
}
