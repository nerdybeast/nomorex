import 'package:supabase_flutter/supabase_flutter.dart';

/// A plain message for a failed admin action. The admin_* functions raise
/// errors as `code: detail`, and the detail isn't written for users.
String adminErrorMessage(Object error) {
  final message = error is PostgrestException ? error.message : '';
  final code = message.split(':').first;
  return switch (code) {
    'forbidden' => "You don't have permission to do that. Your admin role may have been removed.",
    'not_authenticated' => 'Your session has expired. Sign in again.',
    'not_found' => 'That user or role no longer exists.',
    'self' => "You can't remove your own admin role.",
    _ => "Couldn't save the change. Check your connection and try again.",
  };
}
