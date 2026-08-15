import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness.dart';

/// The email/password login screen at `/login`.
class LoginPage {
  LoginPage(this.tester);

  final WidgetTester tester;

  static final emailField = find.byKey(const Key('login_email_field'));
  static final passwordField = find.byKey(const Key('login_password_field'));
  static final submitButton = find.byKey(const Key('login_submit_button'));

  void expectVisible() => expect(emailField, findsOneWidget);

  /// Fills both fields and submits, returning once the login screen has gone.
  ///
  /// Navigation is not driven from here — `_submit` just calls
  /// `AuthNotifier.signIn` and the router redirect reacts to the auth state
  /// change, so the only reliable signal is the login screen disappearing.
  Future<void> signIn(String email, String password) async {
    await tester.enterText(emailField, email);
    await tester.enterText(passwordField, password);
    await tester.pump();

    await tester.tap(submitButton);
    await waitForAbsent(tester, submitButton);
    await tester.pumpAndSettle();
  }
}
