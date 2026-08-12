// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_detail_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(WorkoutDetailNotifier)
final workoutDetailProvider = WorkoutDetailNotifierFamily._();

final class WorkoutDetailNotifierProvider
    extends $AsyncNotifierProvider<WorkoutDetailNotifier, Workout> {
  WorkoutDetailNotifierProvider._({
    required WorkoutDetailNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'workoutDetailProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workoutDetailNotifierHash();

  @override
  String toString() {
    return r'workoutDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  WorkoutDetailNotifier create() => WorkoutDetailNotifier();

  @override
  bool operator ==(Object other) {
    return other is WorkoutDetailNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workoutDetailNotifierHash() =>
    r'66050183d3a3f09cc493f4983aa91875733f096b';

final class WorkoutDetailNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          WorkoutDetailNotifier,
          AsyncValue<Workout>,
          Workout,
          FutureOr<Workout>,
          String
        > {
  WorkoutDetailNotifierFamily._()
    : super(
        retry: null,
        name: r'workoutDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  WorkoutDetailNotifierProvider call(String workoutId) =>
      WorkoutDetailNotifierProvider._(argument: workoutId, from: this);

  @override
  String toString() => r'workoutDetailProvider';
}

abstract class _$WorkoutDetailNotifier extends $AsyncNotifier<Workout> {
  late final _$args = ref.$arg as String;
  String get workoutId => _$args;

  FutureOr<Workout> build(String workoutId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Workout>, Workout>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Workout>, Workout>,
              AsyncValue<Workout>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
