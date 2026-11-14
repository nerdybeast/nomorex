import 'package:supabase_flutter/supabase_flutter.dart';

/// A plain message for a failed admin action. The admin_* functions raise
/// errors as `code: detail`. Most details aren't written for users, but the
/// exercise catalog's `duplicate` and `in_use` ones are (they name the
/// exercise in the way), so those are shown as they are.
String adminErrorMessage(Object error) {
  final message = error is PostgrestException ? error.message : '';
  final code = message.split(':').first;
  final detail = message.contains(':') ? message.substring(message.indexOf(':') + 1).trim() : '';
  return switch (code) {
    'duplicate' || 'in_use' when detail.isNotEmpty => _sentence(detail),
    'forbidden' => "You don't have permission to do that. Your admin role may have been removed.",
    'not_authenticated' => 'Your session has expired. Sign in again.',
    'not_found' => 'That no longer exists. Someone may have just changed it.',
    'self' => "You can't remove your own admin role.",
    _ => "Couldn't save the change. Check your connection and try again.",
  };
}

String _sentence(String detail) {
  final text = detail[0].toUpperCase() + detail.substring(1);
  return text.endsWith('.') ? text : '$text.';
}
