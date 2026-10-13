import 'package:supabase_flutter/supabase_flutter.dart';

/// Explains why a copy can't be made public. Also used as the Public switch's
/// subtitle on copies.
const String kCopyNotShareableMessage = "Copies of other people's content can't be shared.";

/// User-facing message for a failed `copy_workout` / `copy_program` call or a
/// rejected visibility change on a copy.
///
/// The copy RPCs raise `'<code>: <detail>'` (see
/// specs/001-save-community-content/contracts/rpc.md), so this matches on the
/// code prefix rather than the full text.
String copyErrorMessage(Object error) {
  if (error is PostgrestException) {
    if (error.code == '23514') return kCopyNotShareableMessage;
    final code = error.message.split(':').first.trim();
    switch (code) {
      case 'not_authenticated':
        return 'Sign in to save this.';
      case 'not_found':
      case 'archived':
      case 'source_is_copy':
        return 'This is no longer available.';
      case 'copy_is_permanent':
        return kCopyNotShareableMessage;
    }
  }
  return "Couldn't save. Try again.";
}
