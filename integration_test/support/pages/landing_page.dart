import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The unauthenticated landing screen at `/`.
class LandingPage {
  LandingPage(this.tester);

  final WidgetTester tester;

  static final loginButton = find.byKey(const Key('landing_login_button'));

  void expectVisible() => expect(loginButton, findsOneWidget);

  Future<void> tapLogIn() async {
    await tester.tap(loginButton);
    await tester.pumpAndSettle();
  }
}
