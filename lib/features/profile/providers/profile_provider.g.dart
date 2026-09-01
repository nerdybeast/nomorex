// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ProfileNotifier)
final profileProvider = ProfileNotifierProvider._();

final class ProfileNotifierProvider
    extends $AsyncNotifierProvider<ProfileNotifier, Profile?> {
  ProfileNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileNotifierHash();

  @$internal
  @override
  ProfileNotifier create() => ProfileNotifier();
}

String _$profileNotifierHash() => r'a65103207fa5699a46eaf4fe2de786ba36211505';

abstract class _$ProfileNotifier extends $AsyncNotifier<Profile?> {
  FutureOr<Profile?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Profile?>, Profile?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Profile?>, Profile?>,
              AsyncValue<Profile?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Derived provider — returns the user's unit preference ('kg', 'lbs', or
/// 'both'), defaulting to 'both'.

@ProviderFor(unitPreference)
final unitPreferenceProvider = UnitPreferenceProvider._();

/// Derived provider — returns the user's unit preference ('kg', 'lbs', or
/// 'both'), defaulting to 'both'.

final class UnitPreferenceProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  /// Derived provider — returns the user's unit preference ('kg', 'lbs', or
  /// 'both'), defaulting to 'both'.
  UnitPreferenceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'unitPreferenceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$unitPreferenceHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return unitPreference(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$unitPreferenceHash() => r'd98fdd7e693d88e2bcd4f979f31466c340c5b69c';

/// Derived provider — the formula used to estimate a 1RM from a multi-rep PR,
/// defaulting to Brzycki.

@ProviderFor(oneRepMaxFormula)
final oneRepMaxFormulaProvider = OneRepMaxFormulaProvider._();

/// Derived provider — the formula used to estimate a 1RM from a multi-rep PR,
/// defaulting to Brzycki.

final class OneRepMaxFormulaProvider
    extends
        $FunctionalProvider<
          OneRepMaxFormula,
          OneRepMaxFormula,
          OneRepMaxFormula
        >
    with $Provider<OneRepMaxFormula> {
  /// Derived provider — the formula used to estimate a 1RM from a multi-rep PR,
  /// defaulting to Brzycki.
  OneRepMaxFormulaProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'oneRepMaxFormulaProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$oneRepMaxFormulaHash();

  @$internal
  @override
  $ProviderElement<OneRepMaxFormula> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  OneRepMaxFormula create(Ref ref) {
    return oneRepMaxFormula(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OneRepMaxFormula value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OneRepMaxFormula>(value),
    );
  }
}

String _$oneRepMaxFormulaHash() => r'6cec038ccbc6afc73dcfaa9a72e799716498c6e3';

/// The signed-in user's own display name, or null if they haven't set one.

@ProviderFor(displayName)
final displayNameProvider = DisplayNameProvider._();

/// The signed-in user's own display name, or null if they haven't set one.

final class DisplayNameProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  /// The signed-in user's own display name, or null if they haven't set one.
  DisplayNameProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'displayNameProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$displayNameHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return displayName(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$displayNameHash() => r'208c3dfa1df22dcc7f971db42ad147bf69d2e5a0';
