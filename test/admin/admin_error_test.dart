import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/admin/utils/admin_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  String messageFor(String serverMessage) =>
      adminErrorMessage(PostgrestException(message: serverMessage, code: 'P0001'));

  test('maps each server error code to a plain message', () {
    expect(messageFor('forbidden: the admin role is required'), contains("don't have permission"));
    expect(messageFor('not_authenticated: sign in required'), contains('Sign in again'));
    expect(messageFor('not_found: unknown role owner'), contains('no longer exists'));
    expect(messageFor("self: you can't remove your own admin role"), contains('your own admin role'));
  });

  test('never shows the server detail for anything else', () {
    expect(messageFor('invalid_input: enabled must be true or false'), contains('try again'));
    expect(adminErrorMessage(Exception('SocketException: failed host lookup')), contains('connection'));
  });
}
