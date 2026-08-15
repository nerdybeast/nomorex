// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'one_rep_max_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// exerciseId -> the user's heaviest recorded 1-rep PR (kg) for that lift.

@ProviderFor(oneRepMax)
final oneRepMaxProvider = OneRepMaxProvider._();

/// exerciseId -> the user's heaviest recorded 1-rep PR (kg) for that lift.

final class OneRepMaxProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, double>>,
          Map<String, double>,
          FutureOr<Map<String, double>>
        >
    with
        $FutureModifier<Map<String, double>>,
        $FutureProvider<Map<String, double>> {
  /// exerciseId -> the user's heaviest recorded 1-rep PR (kg) for that lift.
  OneRepMaxProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'oneRepMaxProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$oneRepMaxHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, double>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, double>> create(Ref ref) {
    return oneRepMax(ref);
  }
}

String _$oneRepMaxHash() => r'f6d94a4b3422e9cc76a5d19ebdd73e9695e53e5d';

/// Lowercased exercise name -> the user's heaviest recorded 1-rep PR (kg).
///
/// [oneRepMax]'s id keying is enough for the user's own workouts, but misses
/// on someone else's: a public workout's percentage set carries the *owner's*
/// exercise id, while the viewer's PR for the same lift hangs off their own
/// row — a different id for a lift of the same name (that's exactly what
/// `ExercisesNotifier.ensureExerciseByName` creates when a viewer sets a PR
/// from a read-only workout). Matching on name bridges the two so the preview
/// starts resolving instead of offering "set PR" forever.

@ProviderFor(oneRepMaxByName)
final oneRepMaxByNameProvider = OneRepMaxByNameProvider._();

/// Lowercased exercise name -> the user's heaviest recorded 1-rep PR (kg).
///
/// [oneRepMax]'s id keying is enough for the user's own workouts, but misses
/// on someone else's: a public workout's percentage set carries the *owner's*
/// exercise id, while the viewer's PR for the same lift hangs off their own
/// row — a different id for a lift of the same name (that's exactly what
/// `ExercisesNotifier.ensureExerciseByName` creates when a viewer sets a PR
/// from a read-only workout). Matching on name bridges the two so the preview
/// starts resolving instead of offering "set PR" forever.

final class OneRepMaxByNameProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, double>>,
          Map<String, double>,
          FutureOr<Map<String, double>>
        >
    with
        $FutureModifier<Map<String, double>>,
        $FutureProvider<Map<String, double>> {
  /// Lowercased exercise name -> the user's heaviest recorded 1-rep PR (kg).
  ///
  /// [oneRepMax]'s id keying is enough for the user's own workouts, but misses
  /// on someone else's: a public workout's percentage set carries the *owner's*
  /// exercise id, while the viewer's PR for the same lift hangs off their own
  /// row — a different id for a lift of the same name (that's exactly what
  /// `ExercisesNotifier.ensureExerciseByName` creates when a viewer sets a PR
  /// from a read-only workout). Matching on name bridges the two so the preview
  /// starts resolving instead of offering "set PR" forever.
  OneRepMaxByNameProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'oneRepMaxByNameProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$oneRepMaxByNameHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, double>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, double>> create(Ref ref) {
    return oneRepMaxByName(ref);
  }
}

String _$oneRepMaxByNameHash() => r'ee3c8a54c17d012c5e9ecdbf76442cf8daaa0124';
