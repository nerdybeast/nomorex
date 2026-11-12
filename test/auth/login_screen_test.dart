import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nomorex/features/auth/providers/auth_provider.dart';
import 'package:nomorex/features/auth/screens/landing_screen.dart';
import 'package:nomorex/features/auth/screens/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Auth extends AuthNotifier {
  _Auth(this.onSignIn);
  final Future<void> Function(String email, String password) onSignIn;

  @override
  void build() {}

  @override
  Future<void> signIn(String email, String password) => onSignIn(email, password);
}

Future<void> _pump(
  WidgetTester tester, {
  String initial = '/login',
  Future<void> Function(String, String)? onSignIn,
}) async {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(path: '/', builder: (_, _) => const LandingScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    ],
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [authProvider.overrideWith(() => _Auth(onSignIn ?? (_, _) async {}))],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

final _email = find.byKey(const Key('login_email_field'));
final _password = find.byKey(const Key('login_password_field'));
final _submit = find.byKey(const Key('login_submit_button'));

void main() {
  testWidgets('names the product and says how to get back in', (tester) async {
    await _pump(tester);
    expect(find.text('NoMoreX'), findsOneWidget);
    expect(find.text(kForgotPasswordHelp), findsOneWidget);
  });

  testWidgets('empty or malformed input is caught before a round trip', (tester) async {
    var called = false;
    await _pump(tester, onSignIn: (_, _) async => called = true);

    await tester.tap(_submit);
    await tester.pumpAndSettle();
    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);

    await tester.enterText(_email, 'a@');
    await tester.tap(_submit);
    await tester.pumpAndSettle();
    expect(find.text('Enter an email like name@example.com'), findsOneWidget);
    expect(called, isFalse);
  });

  testWidgets('a wrong password shows plain copy, cleared on the next edit', (tester) async {
    await _pump(
      tester,
      onSignIn: (_, _) async => throw const AuthApiException(
        'Invalid login credentials',
        statusCode: '400',
        code: 'invalid_credentials',
      ),
    );
    await tester.enterText(_email, 'a@a.com');
    await tester.enterText(_password, 'wrong');
    await tester.tap(_submit);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login_error')), findsOneWidget);
    expect(find.text("That email and password don't match. Check them and try again."), findsOneWidget);
    expect(find.textContaining('AuthApiException'), findsNothing);

    await tester.enterText(_password, 'wrong2');
    await tester.pump();
    expect(find.byKey(const Key('login_error')), findsNothing);
  });

  testWidgets('the password can be shown and hidden again', (tester) async {
    await _pump(tester);
    EditableText field() => tester.widget<EditableText>(
          find.descendant(of: _password, matching: find.byType(EditableText)),
        );
    expect(field().obscureText, isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(field().obscureText, isFalse);
    await tester.tap(find.byTooltip('Hide password'));
    await tester.pump();
    expect(field().obscureText, isTrue);
  });

  testWidgets('the fields tell password managers what they hold', (tester) async {
    await _pump(tester);
    List<String>? hints(Finder f) =>
        tester.widget<EditableText>(find.descendant(of: f, matching: find.byType(EditableText))).autofillHints?.toList();
    expect(hints(_email), contains('email'));
    expect(hints(_password), ['password']);
  });

  testWidgets('opened directly, Back goes to the landing page', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('login_back_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('landing_login_button')), findsOneWidget);
    expect(find.text(kInviteOnlyNote), findsOneWidget);
  });

  testWidgets('landing goes to /login rather than stacking it', (tester) async {
    await _pump(tester, initial: '/');
    await tester.tap(find.byKey(const Key('landing_login_button')));
    await tester.pumpAndSettle();
    expect(_email, findsOneWidget);
    // Nothing underneath, so the screen offers its own Back to landing.
    expect(find.byKey(const Key('login_back_button')), findsOneWidget);
  });
}
