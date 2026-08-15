import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/harness.dart';
import 'support/pages/landing_page.dart';
import 'support/pages/login_page.dart';
import 'support/pages/my_prs_page.dart';
import 'support/pages/shell_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('auth', () {
    testWidgets('signs in from the landing screen and lands in the shell', (
      tester,
    ) async {
      await bootSignedOut(tester);

      LandingPage(tester).expectVisible();

      await LandingPage(tester).tapLogIn();
      LoginPage(tester).expectVisible();

      await LoginPage(tester).signIn(kTestEmail, kTestPassword);

      // The router redirect — not the login screen — drives this navigation.
      await ShellPage(tester).waitUntilLoaded();
    });

    testWidgets('an authenticated user can load their PRs', (tester) async {
      await bootSignedIn(tester);

      final shell = ShellPage(tester);
      await shell.waitUntilLoaded();
      await shell.goToMyPrs();

      await MyPrsPage(tester).expectLoadedWithoutError();
    });
  });
}
