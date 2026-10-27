// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_copy_count_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// How many (non-archived) copies of another user's public workout the viewer
/// has saved — drives the "You've saved this" hint on the community screen.
/// Invalidated as a whole family by WorkoutsNotifier.saveCommunityWorkout,
/// archiveWorkout, restoreWorkout and deleteWorkoutPermanently, so the hint
/// can't outlive an archived or deleted copy.

@ProviderFor(workoutCopyCount)
final workoutCopyCountProvider = WorkoutCopyCountFamily._();

/// How many (non-archived) copies of another user's public workout the viewer
/// has saved — drives the "You've saved this" hint on the community screen.
/// Invalidated as a whole family by WorkoutsNotifier.saveCommunityWorkout,
/// archiveWorkout, restoreWorkout and deleteWorkoutPermanently, so the hint
/// can't outlive an archived or deleted copy.

final class WorkoutCopyCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  /// How many (non-archived) copies of another user's public workout the viewer
  /// has saved — drives the "You've saved this" hint on the community screen.
  /// Invalidated as a whole family by WorkoutsNotifier.saveCommunityWorkout,
  /// archiveWorkout, restoreWorkout and deleteWorkoutPermanently, so the hint
  /// can't outlive an archived or deleted copy.
  WorkoutCopyCountProvider._({
    required WorkoutCopyCountFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'workoutCopyCountProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$workoutCopyCountHash();

  @override
  String toString() {
    return r'workoutCopyCountProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    final argument = this.argument as String;
    return workoutCopyCount(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkoutCopyCountProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$workoutCopyCountHash() => r'341511c13773c52c7745c44b79d651c281c6f817';

/// How many (non-archived) copies of another user's public workout the viewer
/// has saved — drives the "You've saved this" hint on the community screen.
/// Invalidated as a whole family by WorkoutsNotifier.saveCommunityWorkout,
/// archiveWorkout, restoreWorkout and deleteWorkoutPermanently, so the hint
/// can't outlive an archived or deleted copy.

final class WorkoutCopyCountFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<int>, String> {
  WorkoutCopyCountFamily._()
    : super(
        retry: null,
        name: r'workoutCopyCountProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// How many (non-archived) copies of another user's public workout the viewer
  /// has saved — drives the "You've saved this" hint on the community screen.
  /// Invalidated as a whole family by WorkoutsNotifier.saveCommunityWorkout,
  /// archiveWorkout, restoreWorkout and deleteWorkoutPermanently, so the hint
  /// can't outlive an archived or deleted copy.

  WorkoutCopyCountProvider call(String sourceWorkoutId) =>
      WorkoutCopyCountProvider._(argument: sourceWorkoutId, from: this);

  @override
  String toString() => r'workoutCopyCountProvider';
}
