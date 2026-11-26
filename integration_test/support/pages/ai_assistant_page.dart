import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness.dart';

/// Profile → AI assistant. Nothing here saves or tests a key: saving needs a
/// working keyring (which Linux CI may not have), and testing would call a
/// real provider.
class AiAssistantPage {
  AiAssistantPage(this.tester);

  final WidgetTester tester;

  static final account = find.byKey(const Key('sidebar_account'));
  static final profileButton = find.byKey(const Key('profile_ai_assistant_button'));
  /// The Imports section, in either of its forms.
  static final imports = find.byWidgetPredicate(
    (w) => w.key == const Key('ai_provider_gemini') || w.key == const Key('ai_key_storage_unavailable'),
  );
  static final getKey = find.byKey(const Key('ai_get_key'));
  static final keyStorageUnavailable = find.byKey(const Key('ai_key_storage_unavailable'));
  static Finder provider(String id) => find.byKey(Key('ai_provider_$id'));

  /// From the sidebar's account tile, through Profile.
  Future<void> open() async {
    await waitFor(tester, account);
    await tester.tap(account);
    await waitFor(tester, profileButton);
    await tester.ensureVisible(profileButton);
    await tester.pumpAndSettle();
    await tester.tap(profileButton);
    await waitFor(tester, imports);
    await tester.pumpAndSettle();
  }

  /// True where the device can't store keys (Linux without an unlocked keyring).
  bool get canStoreKeys => keyStorageUnavailable.evaluate().isEmpty;

  Future<void> choose(String id) async {
    await waitFor(tester, provider(id));
    await tester.tap(provider(id));
    await waitFor(tester, getKey);
    await tester.pumpAndSettle();
  }
}
