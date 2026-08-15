import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/harness.dart';
import 'support/pages/add_pr_page.dart';
import 'support/pages/my_prs_page.dart';
import 'support/pages/shell_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('personal bests', () {
    testWidgets('logging a PR persists it and shows it on My PRs', (
      tester,
    ) async {
      // 'Back Squat' is seeded as a predefined exercise and is the only name
      // containing that substring, so the autocomplete filters to one option.
      const exercise = 'Back Squat';

      await bootSignedIn(tester);

      final shell = ShellPage(tester);
      await shell.waitUntilLoaded();
      await shell.createNew('New Personal Best');

      final addPr = AddPrPage(tester);
      await addPr.waitUntilLoaded();
      await addPr.selectExercise(exercise);
      await addPr.setWeight(100);
      await addPr.setReps(1);
      await addPr.save();

      // Saving pops back to the shell; the PR should now come back from
      // Supabase on the My PRs tab.
      await shell.goToMyPrs();
      await MyPrsPage(tester).expectPrCard(exercise);
    });
  });
}
