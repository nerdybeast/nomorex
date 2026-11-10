import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/ai_import_limits.dart';

part 'ai_import_gate_provider.g.dart';

/// Whether the import screen may offer an upload, checked each time it opens
/// with `ai_import_check()`: imports switched off, the one-time notice not yet
/// accepted (`consent_required`), an import already running, or a cap reached.
///
/// The server checks again on upload and on start, so this is only for the
/// user's benefit: they learn they can't import before choosing any files.
@riverpod
class AiImportGateNotifier extends _$AiImportGateNotifier {
  @override
  Future<AiImportCheck> build() async {
    final user = ref.watch(currentAuthUserProvider);
    if (user == null) return const AiImportCheck(allowed: false, reason: 'not_signed_in');
    return fetchCheck();
  }

  /// Records that the user accepted the notice, then checks again.
  Future<void> acceptNotice() async {
    final user = ref.read(currentAuthUserProvider);
    if (user == null) return;
    await recordConsent(user.id);
    ref.invalidateSelf();
    await future;
  }

  Future<void> recheck() async {
    ref.invalidateSelf();
    await future;
  }

  // Network calls, split out so tests can override them.

  Future<AiImportCheck> fetchCheck() async {
    final result = await Supabase.instance.client.rpc('ai_import_check');
    return AiImportCheck.fromJson(Map<String, dynamic>.from(result as Map));
  }

  /// `accepted_at` is the server's clock; users may only insert `user_id`.
  /// Ignores a duplicate, so a double tap or second device is harmless.
  Future<void> recordConsent(String userId) => Supabase.instance.client
      .from('ai_import_consents')
      .upsert({'user_id': userId}, onConflict: 'user_id', ignoreDuplicates: true);
}
