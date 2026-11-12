import 'package:supabase_flutter/supabase_flutter.dart';

/// Plain-language copy for a failed sign-in, each with a next step. Never
/// shows the exception itself: its class name, HTTP status and error code
/// read as a crash to someone who just mistyped a password.
String loginErrorMessage(Object error) {
  if (error is AuthRetryableFetchException) return _offline;
  if (error is AuthException) {
    switch (error.code) {
      case 'invalid_credentials':
        return "That email and password don't match. Check them and try again.";
      case 'email_not_confirmed':
        return 'This email address hasn\'t been confirmed yet. Use the link in the confirmation email, then log in.';
      case 'over_request_rate_limit':
      case 'over_email_send_rate_limit':
        return 'Too many attempts. Wait a minute, then try again.';
      case 'user_banned':
        return 'This account has been suspended. Contact the person who invited you.';
    }
    // A 5xx or a status-less failure is the server or the network, not the
    // user's input.
    final status = int.tryParse(error.statusCode ?? '');
    if (status == null || status >= 500) return _offline;
  }
  final text = error.toString();
  if (text.contains('SocketException') || text.contains('ClientException') || text.contains('Failed to fetch')) {
    return _offline;
  }
  return "Couldn't log you in. Try again in a moment.";
}

const _offline = "Couldn't reach NoMoreX. Check your connection and try again.";
