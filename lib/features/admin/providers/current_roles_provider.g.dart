// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'current_roles_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The signed-in user's roles (`user_roles`, which RLS limits to their own
/// rows). Empty when signed out.
///
/// Only decides what the app shows: every admin function checks the role
/// again on the server.

@ProviderFor(currentUserRoles)
final currentUserRolesProvider = CurrentUserRolesProvider._();

/// The signed-in user's roles (`user_roles`, which RLS limits to their own
/// rows). Empty when signed out.
///
/// Only decides what the app shows: every admin function checks the role
/// again on the server.

final class CurrentUserRolesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Set<String>>,
          Set<String>,
          FutureOr<Set<String>>
        >
    with $FutureModifier<Set<String>>, $FutureProvider<Set<String>> {
  /// The signed-in user's roles (`user_roles`, which RLS limits to their own
  /// rows). Empty when signed out.
  ///
  /// Only decides what the app shows: every admin function checks the role
  /// again on the server.
  CurrentUserRolesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentUserRolesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentUserRolesHash();

  @$internal
  @override
  $FutureProviderElement<Set<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Set<String>> create(Ref ref) {
    return currentUserRoles(ref);
  }
}

String _$currentUserRolesHash() => r'5c5e4995e7fb81a5166aa6dc4b655fa17b388e54';

/// Whether the signed-in user is an admin. False while the roles load or if
/// they couldn't be read.

@ProviderFor(isAdmin)
final isAdminProvider = IsAdminProvider._();

/// Whether the signed-in user is an admin. False while the roles load or if
/// they couldn't be read.

final class IsAdminProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether the signed-in user is an admin. False while the roles load or if
  /// they couldn't be read.
  IsAdminProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isAdminProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isAdminHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return isAdmin(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isAdminHash() => r'01810d3bb1ab3208f27919afdd6e8aedfa1dc4e3';
