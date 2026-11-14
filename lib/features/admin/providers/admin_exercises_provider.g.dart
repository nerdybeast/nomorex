// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_exercises_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One page of official exercises A–Z, active or [retired], matching [search]
/// (name, alias or slug). Re-read on every visit, like the users list.

@ProviderFor(AdminExercisesNotifier)
final adminExercisesProvider = AdminExercisesNotifierFamily._();

/// One page of official exercises A–Z, active or [retired], matching [search]
/// (name, alias or slug). Re-read on every visit, like the users list.
final class AdminExercisesNotifierProvider
    extends
        $AsyncNotifierProvider<
          AdminExercisesNotifier,
          AdminPage<AdminExercise>
        > {
  /// One page of official exercises A–Z, active or [retired], matching [search]
  /// (name, alias or slug). Re-read on every visit, like the users list.
  AdminExercisesNotifierProvider._({
    required AdminExercisesNotifierFamily super.from,
    required ({String search, bool retired, int page}) super.argument,
  }) : super(
         retry: null,
         name: r'adminExercisesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$adminExercisesNotifierHash();

  @override
  String toString() {
    return r'adminExercisesProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  AdminExercisesNotifier create() => AdminExercisesNotifier();

  @override
  bool operator ==(Object other) {
    return other is AdminExercisesNotifierProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$adminExercisesNotifierHash() =>
    r'2aab60d3a09679a8c9a1f79aa0df4119efc0fed0';

/// One page of official exercises A–Z, active or [retired], matching [search]
/// (name, alias or slug). Re-read on every visit, like the users list.

final class AdminExercisesNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          AdminExercisesNotifier,
          AsyncValue<AdminPage<AdminExercise>>,
          AdminPage<AdminExercise>,
          FutureOr<AdminPage<AdminExercise>>,
          ({String search, bool retired, int page})
        > {
  AdminExercisesNotifierFamily._()
    : super(
        retry: null,
        name: r'adminExercisesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One page of official exercises A–Z, active or [retired], matching [search]
  /// (name, alias or slug). Re-read on every visit, like the users list.

  AdminExercisesNotifierProvider call({
    required String search,
    required bool retired,
    required int page,
  }) => AdminExercisesNotifierProvider._(
    argument: (search: search, retired: retired, page: page),
    from: this,
  );

  @override
  String toString() => r'adminExercisesProvider';
}

/// One page of official exercises A–Z, active or [retired], matching [search]
/// (name, alias or slug). Re-read on every visit, like the users list.

abstract class _$AdminExercisesNotifier
    extends $AsyncNotifier<AdminPage<AdminExercise>> {
  late final _$args = ref.$arg as ({String search, bool retired, int page});
  String get search => _$args.search;
  bool get retired => _$args.retired;
  int get page => _$args.page;

  FutureOr<AdminPage<AdminExercise>> build({
    required String search,
    required bool retired,
    required int page,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<AdminPage<AdminExercise>>,
              AdminPage<AdminExercise>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<AdminPage<AdminExercise>>,
                AdminPage<AdminExercise>
              >,
              AsyncValue<AdminPage<AdminExercise>>,
              Object?,
              Object?
            >;
    element.handleCreate(
      ref,
      () => build(
        search: _$args.search,
        retired: _$args.retired,
        page: _$args.page,
      ),
    );
  }
}

/// Creates, edits, retires, restores, deletes and exports official exercises.
/// Loading while a change is saved; each change rethrows on failure after
/// leaving the error in its state.
///
/// After a change it re-reads the admin lists, the audit log, and this
/// device's exercise catalog and name-keyed 1RMs (aliases are keys there).
/// Workout and program lists cache exercise names too and show a rename the
/// next time they load; other users see every change on their next load.

@ProviderFor(AdminExerciseActionsNotifier)
final adminExerciseActionsProvider = AdminExerciseActionsNotifierProvider._();

/// Creates, edits, retires, restores, deletes and exports official exercises.
/// Loading while a change is saved; each change rethrows on failure after
/// leaving the error in its state.
///
/// After a change it re-reads the admin lists, the audit log, and this
/// device's exercise catalog and name-keyed 1RMs (aliases are keys there).
/// Workout and program lists cache exercise names too and show a rename the
/// next time they load; other users see every change on their next load.
final class AdminExerciseActionsNotifierProvider
    extends $AsyncNotifierProvider<AdminExerciseActionsNotifier, void> {
  /// Creates, edits, retires, restores, deletes and exports official exercises.
  /// Loading while a change is saved; each change rethrows on failure after
  /// leaving the error in its state.
  ///
  /// After a change it re-reads the admin lists, the audit log, and this
  /// device's exercise catalog and name-keyed 1RMs (aliases are keys there).
  /// Workout and program lists cache exercise names too and show a rename the
  /// next time they load; other users see every change on their next load.
  AdminExerciseActionsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'adminExerciseActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$adminExerciseActionsNotifierHash();

  @$internal
  @override
  AdminExerciseActionsNotifier create() => AdminExerciseActionsNotifier();
}

String _$adminExerciseActionsNotifierHash() =>
    r'1e33fe6412be7b62680eee0dd0a2dc105b7bda85';

/// Creates, edits, retires, restores, deletes and exports official exercises.
/// Loading while a change is saved; each change rethrows on failure after
/// leaving the error in its state.
///
/// After a change it re-reads the admin lists, the audit log, and this
/// device's exercise catalog and name-keyed 1RMs (aliases are keys there).
/// Workout and program lists cache exercise names too and show a rename the
/// next time they load; other users see every change on their next load.

abstract class _$AdminExerciseActionsNotifier extends $AsyncNotifier<void> {
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
