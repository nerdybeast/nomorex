import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/smoke_test_result.dart';
import '../utils/genkit_call.dart';

part 'ai_smoke_test_provider.g.dart';

/// Runs the `smokeTest` Genkit flow on demand from the Profile screen's
/// debug-only "Test AI connection" button.
///
/// State is `null` until the first run. Auto-disposed (not keepAlive): it's
/// a one-off diagnostic, not cached data. It still resets on auth changes so
/// a result from one user never survives a sign-out. That's done through
/// [currentAuthUserProvider] (which itself watches `authStateProvider`)
/// rather than `authStateProvider` directly, because widget tests override
/// the former and the latter reads `Supabase.instance`.
@riverpod
class AiSmokeTestNotifier extends _$AiSmokeTestNotifier {
  @override
  Future<SmokeTestResult?> build() async {
    ref.watch(currentAuthUserProvider);
    return null;
  }

  Future<void> run() async {
    state = const AsyncLoading();
    try {
      final result = await callFlow();
      state = AsyncData(result);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// The network call, split out so widget tests can override it.
  Future<SmokeTestResult> callFlow() async {
    final result = await callGenkitFlow(Supabase.instance.client.functions, 'smokeTest');
    return SmokeTestResult.fromJson(Map<String, dynamic>.from(result as Map));
  }
}
