// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_smoke_test_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Runs the `smokeTest` Genkit flow on demand from the Profile screen's
/// debug-only "Test AI connection" button.
///
/// State is `null` until the first run. Auto-disposed (not keepAlive): it's
/// a one-off diagnostic, not cached data. It still resets on auth changes so
/// a result from one user never survives a sign-out. That's done through
/// [currentAuthUserProvider] (which itself watches `authStateProvider`)
/// rather than `authStateProvider` directly, because widget tests override
/// the former and the latter reads `Supabase.instance`.

@ProviderFor(AiSmokeTestNotifier)
final aiSmokeTestProvider = AiSmokeTestNotifierProvider._();

/// Runs the `smokeTest` Genkit flow on demand from the Profile screen's
/// debug-only "Test AI connection" button.
///
/// State is `null` until the first run. Auto-disposed (not keepAlive): it's
/// a one-off diagnostic, not cached data. It still resets on auth changes so
/// a result from one user never survives a sign-out. That's done through
/// [currentAuthUserProvider] (which itself watches `authStateProvider`)
/// rather than `authStateProvider` directly, because widget tests override
/// the former and the latter reads `Supabase.instance`.
final class AiSmokeTestNotifierProvider
    extends $AsyncNotifierProvider<AiSmokeTestNotifier, SmokeTestResult?> {
  /// Runs the `smokeTest` Genkit flow on demand from the Profile screen's
  /// debug-only "Test AI connection" button.
  ///
  /// State is `null` until the first run. Auto-disposed (not keepAlive): it's
  /// a one-off diagnostic, not cached data. It still resets on auth changes so
  /// a result from one user never survives a sign-out. That's done through
  /// [currentAuthUserProvider] (which itself watches `authStateProvider`)
  /// rather than `authStateProvider` directly, because widget tests override
  /// the former and the latter reads `Supabase.instance`.
  AiSmokeTestNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiSmokeTestProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiSmokeTestNotifierHash();

  @$internal
  @override
  AiSmokeTestNotifier create() => AiSmokeTestNotifier();
}

String _$aiSmokeTestNotifierHash() =>
    r'cf4d39eb435bad02dca484b3bf4a2db4a63e6260';

/// Runs the `smokeTest` Genkit flow on demand from the Profile screen's
/// debug-only "Test AI connection" button.
///
/// State is `null` until the first run. Auto-disposed (not keepAlive): it's
/// a one-off diagnostic, not cached data. It still resets on auth changes so
/// a result from one user never survives a sign-out. That's done through
/// [currentAuthUserProvider] (which itself watches `authStateProvider`)
/// rather than `authStateProvider` directly, because widget tests override
/// the former and the latter reads `Supabase.instance`.

abstract class _$AiSmokeTestNotifier extends $AsyncNotifier<SmokeTestResult?> {
  FutureOr<SmokeTestResult?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<SmokeTestResult?>, SmokeTestResult?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<SmokeTestResult?>, SmokeTestResult?>,
              AsyncValue<SmokeTestResult?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
