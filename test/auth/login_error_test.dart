import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/auth/utils/login_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('wrong credentials read as a mismatch, not an exception', () {
    final msg = loginErrorMessage(
      const AuthApiException('Invalid login credentials', statusCode: '400', code: 'invalid_credentials'),
    );
    expect(msg, "That email and password don't match. Check them and try again.");
    expect(msg, isNot(contains('Exception')));
  });

  test('rate limits ask the lifter to wait', () {
    expect(
      loginErrorMessage(const AuthApiException('slow down', statusCode: '429', code: 'over_request_rate_limit')),
      contains('Wait a minute'),
    );
  });

  test('network and server failures say it is the connection', () {
    const offline = "Couldn't reach NoMoreX. Check your connection and try again.";
    expect(loginErrorMessage(AuthRetryableFetchException(message: 'Failed host lookup')), offline);
    expect(loginErrorMessage(const AuthApiException('boom', statusCode: '503')), offline);
    expect(loginErrorMessage(Exception('ClientException: Failed to fetch')), offline);
  });

  test('anything else gets a generic retry, never the raw error', () {
    final msg = loginErrorMessage(StateError('weird internal thing'));
    expect(msg, "Couldn't log you in. Try again in a moment.");
  });
}
