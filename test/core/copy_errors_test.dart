import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/core/utils/copy_errors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException _rpcError(String message, {String code = 'P0001'}) =>
    PostgrestException(message: message, code: code);

void main() {
  test('not_authenticated asks the user to sign in', () {
    expect(copyErrorMessage(_rpcError('not_authenticated: sign in required')),
        'Sign in to save this.');
  });

  test('missing, archived and copied sources read as no longer available', () {
    for (final code in ['not_found', 'archived', 'source_is_copy']) {
      expect(copyErrorMessage(_rpcError('$code: whatever')), 'This is no longer available.');
    }
  });

  test('un-marking or publishing a copy explains copies cannot be shared', () {
    expect(copyErrorMessage(_rpcError('copy_is_permanent: a copy cannot be un-marked')),
        kCopyNotShareableMessage);
    expect(
      copyErrorMessage(_rpcError('new row violates check constraint', code: '23514')),
      kCopyNotShareableMessage,
    );
  });

  test('anything else is a generic retryable failure', () {
    expect(copyErrorMessage(_rpcError('own_content: already yours')), "Couldn't save. Try again.");
    expect(copyErrorMessage(Exception('socket closed')), "Couldn't save. Try again.");
  });
}
