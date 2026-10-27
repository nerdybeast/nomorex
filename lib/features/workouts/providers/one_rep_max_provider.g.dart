// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'one_rep_max_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// exerciseId -> the user's current 1RM (kg) for that lift: their latest PR
/// entry, estimated when it isn't a single. See [foldOneRepMaxes].

@ProviderFor(oneRepMax)
final oneRepMaxProvider = OneRepMaxProvider._();

/// exerciseId -> the user's current 1RM (kg) for that lift: their latest PR
/// entry, estimated when it isn't a single. See [foldOneRepMaxes].

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
  /// exerciseId -> the user's current 1RM (kg) for that lift: their latest PR
  /// entry, estimated when it isn't a single. See [foldOneRepMaxes].
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

String _$oneRepMaxHash() => r'69d41be518cb1bcfc9a3af664d1e7d6ab86dc87e';

/// Lowercased exercise name -> the user's current 1RM (kg), by the same
/// latest-entry rule as [oneRepMax].
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

/// Lowercased exercise name -> the user's current 1RM (kg), by the same
/// latest-entry rule as [oneRepMax].
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
  /// Lowercased exercise name -> the user's current 1RM (kg), by the same
  /// latest-entry rule as [oneRepMax].
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

String _$oneRepMaxByNameHash() => r'4d8cdd2cff1b1de3bcb2a1a3e864c3ecedf6663d';
