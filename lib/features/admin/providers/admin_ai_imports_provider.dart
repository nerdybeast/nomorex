import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../ai/providers/ai_import_gate_provider.dart';
import '../../ai/providers/ai_import_intake_provider.dart';

part 'admin_ai_imports_provider.g.dart';

/// The AI import on/off switch on the admin screen. The value itself is read
/// from [aiImportLimitsProvider]; this only changes it. Loading while a change
/// is being saved.
@riverpod
class AdminAiImportsNotifier extends _$AdminAiImportsNotifier {
  @override
  FutureOr<void> build() {}

  /// Turns imports on or off for everyone, then re-reads the limits so
  /// `AiImportButton` shows or hides on this device straight away. Other
  /// devices pick it up on their next launch or resume. Rethrows on failure,
  /// after leaving the error in [state].
  Future<void> setEnabled(bool enabled) async {
    state = const AsyncLoading();
    try {
      await callSetEnabled(enabled);
      ref.invalidate(aiImportLimitsProvider);
      ref.invalidate(aiImportGateProvider);
      await ref.read(aiImportLimitsProvider.future);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  // Network call, split out so tests can override it.
  Future<void> callSetEnabled(bool enabled) =>
      Supabase.instance.client.rpc('admin_set_ai_imports_enabled', params: {'p_enabled': enabled});
}
