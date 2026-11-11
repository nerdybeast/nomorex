import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/core/constants/app_constants.dart';

// web/privacy.html is published with the web app and linked from Profile, App
// Store Connect and Play Console (see AppConstants.privacyPolicyUrl).
void main() {
  final policy = File('web/privacy.html');

  test('is published from web/ at the URL the app links to', () {
    expect(policy.existsSync(), isTrue);
    expect(AppConstants.privacyPolicyUrl, endsWith('/privacy.html'));
  });

  test('has the sections the stores look for', () {
    final html = policy.readAsStringSync();
    // Google Play asks for a link where users can request account deletion;
    // App Store Connect points at the policy as a whole.
    for (final id in ['collect', 'ai-import', 'providers', 'retention', 'delete-account', 'contact']) {
      expect(html, contains('id="$id"'), reason: 'missing section #$id');
    }
  });

  test('has no placeholders left', () {
    // Drafts mark what only the owner can fill in (contact address, retention
    // periods, data region) with class="todo". None may ship.
    final todos = RegExp(r'class="todo">([^<]*)<')
        .allMatches(policy.readAsStringSync())
        .map((m) => m.group(1))
        .toSet();
    expect(todos, isEmpty, reason: 'fill in: ${todos.join(', ')}');
  });
}
