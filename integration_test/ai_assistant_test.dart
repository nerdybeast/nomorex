import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/harness.dart';
import 'support/pages/ai_assistant_page.dart';
import 'support/pages/shell_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('AI assistant settings', () {
    testWidgets('opens from Profile and shows the key panel for the chosen provider', (tester) async {
      await bootSignedIn(tester);
      await ShellPage(tester).waitUntilLoaded();
      final settings = AiAssistantPage(tester);
      await settings.open();

      expect(AiAssistantPage.imports, findsOneWidget);
      // Linux runners may have no keyring; the screen says so instead.
      if (!settings.canStoreKeys) return;
      await settings.choose('anthropic');
      expect(find.text('Claude API key'), findsOneWidget);
      await settings.choose('gemini');
      expect(find.text('Gemini API key'), findsOneWidget);
    });
  });
}
