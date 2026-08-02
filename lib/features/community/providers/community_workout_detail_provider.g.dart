// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'community_workout_detail_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CommunityWorkoutDetailNotifier)
final communityWorkoutDetailProvider = CommunityWorkoutDetailNotifierFamily._();

final class CommunityWorkoutDetailNotifierProvider
    extends $AsyncNotifierProvider<CommunityWorkoutDetailNotifier, Workout> {
  CommunityWorkoutDetailNotifierProvider._({
    required CommunityWorkoutDetailNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'communityWorkoutDetailProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$communityWorkoutDetailNotifierHash();

  @override
  String toString() {
    return r'communityWorkoutDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  CommunityWorkoutDetailNotifier create() => CommunityWorkoutDetailNotifier();

  @override
  bool operator ==(Object other) {
    return other is CommunityWorkoutDetailNotifierProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$communityWorkoutDetailNotifierHash() =>
    r'7bf8ce58aa99b8ca6c9dde074977f4a788efdf91';

final class CommunityWorkoutDetailNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          CommunityWorkoutDetailNotifier,
          AsyncValue<Workout>,
          Workout,
          FutureOr<Workout>,
          String
        > {
  CommunityWorkoutDetailNotifierFamily._()
    : super(
        retry: null,
        name: r'communityWorkoutDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  CommunityWorkoutDetailNotifierProvider call(String workoutId) =>
      CommunityWorkoutDetailNotifierProvider._(argument: workoutId, from: this);

  @override
  String toString() => r'communityWorkoutDetailProvider';
}

abstract class _$CommunityWorkoutDetailNotifier
    extends $AsyncNotifier<Workout> {
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
