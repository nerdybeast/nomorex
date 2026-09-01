// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'one_rep_max_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// exerciseId -> the user's 1RM (kg) for that lift: their heaviest recorded
/// single, or — when they've never tested one — the best estimate from their
/// multi-rep PRs.

@ProviderFor(oneRepMax)
final oneRepMaxProvider = OneRepMaxProvider._();

/// exerciseId -> the user's 1RM (kg) for that lift: their heaviest recorded
/// single, or — when they've never tested one — the best estimate from their
/// multi-rep PRs.

final class OneRepMaxProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, OneRepMax>>,
          Map<String, OneRepMax>,
          FutureOr<Map<String, OneRepMax>>
        >
    with
        $FutureModifier<Map<String, OneRepMax>>,
        $FutureProvider<Map<String, OneRepMax>> {
  /// exerciseId -> the user's 1RM (kg) for that lift: their heaviest recorded
  /// single, or — when they've never tested one — the best estimate from their
  /// multi-rep PRs.
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
  $FutureProviderElement<Map<String, OneRepMax>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, OneRepMax>> create(Ref ref) {
    return oneRepMax(ref);
  }
}

String _$oneRepMaxHash() => r'c56233de095327bb91b0a15be4399cc6a7eeff0f';

/// Lowercased exercise name -> the user's 1RM (kg), measured or estimated.
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

/// Lowercased exercise name -> the user's 1RM (kg), measured or estimated.
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
          AsyncValue<Map<String, OneRepMax>>,
          Map<String, OneRepMax>,
          FutureOr<Map<String, OneRepMax>>
        >
    with
        $FutureModifier<Map<String, OneRepMax>>,
        $FutureProvider<Map<String, OneRepMax>> {
  /// Lowercased exercise name -> the user's 1RM (kg), measured or estimated.
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
  $FutureProviderElement<Map<String, OneRepMax>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, OneRepMax>> create(Ref ref) {
    return oneRepMaxByName(ref);
  }
}

String _$oneRepMaxByNameHash() => r'0d8b785ad3dac9f5dcdf5cf9c100565cb4e62164';
