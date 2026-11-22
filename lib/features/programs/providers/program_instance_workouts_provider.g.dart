// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'program_instance_workouts_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Maps a program instance's materialized workouts back to the session each
/// one was generated from (`workoutKey`: its `program_session_id`, or its
/// `program_day_id` when it has none), so a day's session rows can push
/// straight to the real, loggable workout.

@ProviderFor(ProgramInstanceWorkoutsNotifier)
final programInstanceWorkoutsProvider =
    ProgramInstanceWorkoutsNotifierFamily._();

/// Maps a program instance's materialized workouts back to the session each
/// one was generated from (`workoutKey`: its `program_session_id`, or its
/// `program_day_id` when it has none), so a day's session rows can push
/// straight to the real, loggable workout.
final class ProgramInstanceWorkoutsNotifierProvider
    extends
        $AsyncNotifierProvider<
          ProgramInstanceWorkoutsNotifier,
          Map<String, String>
        > {
  /// Maps a program instance's materialized workouts back to the session each
  /// one was generated from (`workoutKey`: its `program_session_id`, or its
  /// `program_day_id` when it has none), so a day's session rows can push
  /// straight to the real, loggable workout.
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
    r'bf782a5549b90f710b8532a3f346b0d6fdd220af';

/// Maps a program instance's materialized workouts back to the session each
/// one was generated from (`workoutKey`: its `program_session_id`, or its
/// `program_day_id` when it has none), so a day's session rows can push
/// straight to the real, loggable workout.

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

  /// Maps a program instance's materialized workouts back to the session each
  /// one was generated from (`workoutKey`: its `program_session_id`, or its
  /// `program_day_id` when it has none), so a day's session rows can push
  /// straight to the real, loggable workout.

  ProgramInstanceWorkoutsNotifierProvider call(String instanceId) =>
      ProgramInstanceWorkoutsNotifierProvider._(
        argument: instanceId,
        from: this,
      );

  @override
  String toString() => r'programInstanceWorkoutsProvider';
}

/// Maps a program instance's materialized workouts back to the session each
/// one was generated from (`workoutKey`: its `program_session_id`, or its
/// `program_day_id` when it has none), so a day's session rows can push
/// straight to the real, loggable workout.

abstract class _$ProgramInstanceWorkoutsNotifier
    extends $AsyncNotifier<Map<String, String>> {
  late final _$args = ref.$arg as String;
  String get instanceId => _$args;

  FutureOr<Map<String, String>> build(String instanceId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
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
    return element.handleCreate(ref, () => build(_$args));
  }
}
