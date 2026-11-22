// Every E2E file in one entry point, so `scripts/e2e.sh` builds and launches
// the desktop app once instead of once per file.
//
// A new `*_test.dart` file goes in here too: import it with a prefix and call
// its `main()` below. `scripts/e2e.sh` refuses to run while a file is missing,
// so a test can't be skipped without anyone noticing.
//
// Each file still runs on its own for debugging:
//   ./scripts/e2e.sh --file integration_test/app_test.dart
//
// The files share one process and one database, in this order. Every test boots
// its own app and signs in again (see support/harness.dart), so none inherits
// another's screen state, and the assertions check presence rather than counts,
// so none depends on another's data.
import 'package:integration_test/integration_test.dart';

import 'ai_import_test.dart' as ai_import;
import 'app_test.dart' as app;
import 'community_copy_test.dart' as community_copy;
import 'personal_best_test.dart' as personal_best;
import 'program_sessions_test.dart' as program_sessions;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  app.main();
  personal_best.main();
  ai_import.main();
  community_copy.main();
  program_sessions.main();
}
