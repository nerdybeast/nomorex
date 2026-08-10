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

String _$profileNotifierHash() => r'5f7ac23068dfbdc0f1581b6322bc09ae087cc9b1';

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
