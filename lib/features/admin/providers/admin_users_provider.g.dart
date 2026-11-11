// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_users_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One page of users matching [search] (email or display name), newest first.
/// Re-read on every visit rather than kept alive: admins expect a fresh list.

@ProviderFor(AdminUsersNotifier)
final adminUsersProvider = AdminUsersNotifierFamily._();

/// One page of users matching [search] (email or display name), newest first.
/// Re-read on every visit rather than kept alive: admins expect a fresh list.
final class AdminUsersNotifierProvider
    extends $AsyncNotifierProvider<AdminUsersNotifier, AdminPage<AdminUser>> {
  /// One page of users matching [search] (email or display name), newest first.
  /// Re-read on every visit rather than kept alive: admins expect a fresh list.
  AdminUsersNotifierProvider._({
    required AdminUsersNotifierFamily super.from,
    required ({String search, int page}) super.argument,
  }) : super(
         retry: null,
         name: r'adminUsersProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$adminUsersNotifierHash();

  @override
  String toString() {
    return r'adminUsersProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  AdminUsersNotifier create() => AdminUsersNotifier();

  @override
  bool operator ==(Object other) {
    return other is AdminUsersNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$adminUsersNotifierHash() =>
    r'4832083ebba5f9cf3ada6ab49b1d146860e58d3d';

/// One page of users matching [search] (email or display name), newest first.
/// Re-read on every visit rather than kept alive: admins expect a fresh list.

final class AdminUsersNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          AdminUsersNotifier,
          AsyncValue<AdminPage<AdminUser>>,
          AdminPage<AdminUser>,
          FutureOr<AdminPage<AdminUser>>,
          ({String search, int page})
        > {
  AdminUsersNotifierFamily._()
    : super(
        retry: null,
        name: r'adminUsersProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One page of users matching [search] (email or display name), newest first.
  /// Re-read on every visit rather than kept alive: admins expect a fresh list.

  AdminUsersNotifierProvider call({
    required String search,
    required int page,
  }) => AdminUsersNotifierProvider._(
    argument: (search: search, page: page),
    from: this,
  );

  @override
  String toString() => r'adminUsersProvider';
}

/// One page of users matching [search] (email or display name), newest first.
/// Re-read on every visit rather than kept alive: admins expect a fresh list.

abstract class _$AdminUsersNotifier
    extends $AsyncNotifier<AdminPage<AdminUser>> {
  late final _$args = ref.$arg as ({String search, int page});
  String get search => _$args.search;
  int get page => _$args.page;

  FutureOr<AdminPage<AdminUser>> build({
    required String search,
    required int page,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<AdminPage<AdminUser>>, AdminPage<AdminUser>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<AdminPage<AdminUser>>,
                AdminPage<AdminUser>
              >,
              AsyncValue<AdminPage<AdminUser>>,
              Object?,
              Object?
            >;
    element.handleCreate(
      ref,
      () => build(search: _$args.search, page: _$args.page),
    );
  }
}

/// One page of the admin audit log, newest first.

@ProviderFor(AdminAuditLogNotifier)
final adminAuditLogProvider = AdminAuditLogNotifierFamily._();

/// One page of the admin audit log, newest first.
final class AdminAuditLogNotifierProvider
    extends
        $AsyncNotifierProvider<
          AdminAuditLogNotifier,
          AdminPage<AdminAuditEntry>
        > {
  /// One page of the admin audit log, newest first.
  AdminAuditLogNotifierProvider._({
    required AdminAuditLogNotifierFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'adminAuditLogProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$adminAuditLogNotifierHash();

  @override
  String toString() {
    return r'adminAuditLogProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  AdminAuditLogNotifier create() => AdminAuditLogNotifier();

  @override
  bool operator ==(Object other) {
    return other is AdminAuditLogNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$adminAuditLogNotifierHash() =>
    r'1de1317da1b27b2700c1d9a332538dce4f0cb510';

/// One page of the admin audit log, newest first.

final class AdminAuditLogNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          AdminAuditLogNotifier,
          AsyncValue<AdminPage<AdminAuditEntry>>,
          AdminPage<AdminAuditEntry>,
          FutureOr<AdminPage<AdminAuditEntry>>,
          int
        > {
  AdminAuditLogNotifierFamily._()
    : super(
        retry: null,
        name: r'adminAuditLogProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One page of the admin audit log, newest first.

  AdminAuditLogNotifierProvider call({required int page}) =>
      AdminAuditLogNotifierProvider._(argument: page, from: this);

  @override
  String toString() => r'adminAuditLogProvider';
}

/// One page of the admin audit log, newest first.

abstract class _$AdminAuditLogNotifier
    extends $AsyncNotifier<AdminPage<AdminAuditEntry>> {
  late final _$args = ref.$arg as int;
  int get page => _$args;

  FutureOr<AdminPage<AdminAuditEntry>> build({required int page});
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<AdminPage<AdminAuditEntry>>,
              AdminPage<AdminAuditEntry>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<AdminPage<AdminAuditEntry>>,
                AdminPage<AdminAuditEntry>
              >,
              AsyncValue<AdminPage<AdminAuditEntry>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(page: _$args));
  }
}

/// Every role a user can be given, for the switches on a user's details. A
/// role added on the server shows up here with no app change.

@ProviderFor(availableRoles)
final availableRolesProvider = AvailableRolesProvider._();

/// Every role a user can be given, for the switches on a user's details. A
/// role added on the server shows up here with no app change.

final class AvailableRolesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RoleInfo>>,
          List<RoleInfo>,
          FutureOr<List<RoleInfo>>
        >
    with $FutureModifier<List<RoleInfo>>, $FutureProvider<List<RoleInfo>> {
  /// Every role a user can be given, for the switches on a user's details. A
  /// role added on the server shows up here with no app change.
  AvailableRolesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'availableRolesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$availableRolesHash();

  @$internal
  @override
  $FutureProviderElement<List<RoleInfo>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<RoleInfo>> create(Ref ref) {
    return availableRoles(ref);
  }
}

String _$availableRolesHash() => r'045afeb3e8aee7820a74d3ff852625f3cb9eb94a';

/// Grants and revokes roles. Loading while a change is saved; rethrows on
/// failure after leaving the error in its state.

@ProviderFor(AdminRolesNotifier)
final adminRolesProvider = AdminRolesNotifierProvider._();

/// Grants and revokes roles. Loading while a change is saved; rethrows on
/// failure after leaving the error in its state.
final class AdminRolesNotifierProvider
    extends $AsyncNotifierProvider<AdminRolesNotifier, void> {
  /// Grants and revokes roles. Loading while a change is saved; rethrows on
  /// failure after leaving the error in its state.
  AdminRolesNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'adminRolesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$adminRolesNotifierHash();

  @$internal
  @override
  AdminRolesNotifier create() => AdminRolesNotifier();
}

String _$adminRolesNotifierHash() =>
    r'4d4632ab726b0dd8e94224fa01654f418287330f';

/// Grants and revokes roles. Loading while a change is saved; rethrows on
/// failure after leaving the error in its state.

abstract class _$AdminRolesNotifier extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
