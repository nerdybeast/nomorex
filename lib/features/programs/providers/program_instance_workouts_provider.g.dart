// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'program_instance_workouts_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Maps a program instance's materialized workouts back to the
/// `program_day_id` each one was generated from, so a day card can push
/// straight to the real, loggable workout for that day.

@ProviderFor(ProgramInstanceWorkoutsNotifier)
final programInstanceWorkoutsProvider =
    ProgramInstanceWorkoutsNotifierFamily._();

/// Maps a program instance's materialized workouts back to the
/// `program_day_id` each one was generated from, so a day card can push
/// straight to the real, loggable workout for that day.
final class ProgramInstanceWorkoutsNotifierProvider
    extends
        $AsyncNotifierProvider<
          ProgramInstanceWorkoutsNotifier,
          Map<String, String>
        > {
  /// Maps a program instance's materialized workouts back to the
  /// `program_day_id` each one was generated from, so a day card can push
  /// straight to the real, loggable workout for that day.
  ProgramInstanceWorkoutsNotifierProvider._({
    required ProgramInstanceWorkoutsNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'programInstanceWorkoutsProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$programInstanceWorkoutsNotifierHash();

  @override
  String toString() {
    return r'programInstanceWorkoutsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ProgramInstanceWorkoutsNotifier create() => ProgramInstanceWorkoutsNotifier();

  @override
  bool operator ==(Object other) {
    return other is ProgramInstanceWorkoutsNotifierProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$programInstanceWorkoutsNotifierHash() =>
    r'38b2b20f6fdaa37421a28416d1e17fc3cc3d42f3';

/// Maps a program instance's materialized workouts back to the
/// `program_day_id` each one was generated from, so a day card can push
/// straight to the real, loggable workout for that day.

final class ProgramInstanceWorkoutsNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          ProgramInstanceWorkoutsNotifier,
          AsyncValue<Map<String, String>>,
          Map<String, String>,
          FutureOr<Map<String, String>>,
          String
        > {
  ProgramInstanceWorkoutsNotifierFamily._()
    : super(
        retry: null,
        name: r'programInstanceWorkoutsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Maps a program instance's materialized workouts back to the
  /// `program_day_id` each one was generated from, so a day card can push
  /// straight to the real, loggable workout for that day.

  ProgramInstanceWorkoutsNotifierProvider call(String instanceId) =>
      ProgramInstanceWorkoutsNotifierProvider._(
        argument: instanceId,
        from: this,
      );

  @override
  String toString() => r'programInstanceWorkoutsProvider';
}

/// Maps a program instance's materialized workouts back to the
/// `program_day_id` each one was generated from, so a day card can push
/// straight to the real, loggable workout for that day.

abstract class _$ProgramInstanceWorkoutsNotifier
    extends $AsyncNotifier<Map<String, String>> {
  late final _$args = ref.$arg as String;
  String get instanceId => _$args;

  FutureOr<Map<String, String>> build(String instanceId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<Map<String, String>>, Map<String, String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Map<String, String>>, Map<String, String>>,
              AsyncValue<Map<String, String>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
