// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recent_exercises_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The ids of the exercises the user most recently added to a workout or a
/// program day, newest first and without repeats.
///
/// Auto-disposed rather than `keepAlive`: only the exercise picker watches
/// it, and re-reading each time the picker opens keeps it current without
/// every add-exercise path having to invalidate it.

@ProviderFor(recentExerciseIds)
final recentExerciseIdsProvider = RecentExerciseIdsProvider._();

/// The ids of the exercises the user most recently added to a workout or a
/// program day, newest first and without repeats.
///
/// Auto-disposed rather than `keepAlive`: only the exercise picker watches
/// it, and re-reading each time the picker opens keeps it current without
/// every add-exercise path having to invalidate it.

final class RecentExerciseIdsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<String>>,
          List<String>,
          FutureOr<List<String>>
        >
    with $FutureModifier<List<String>>, $FutureProvider<List<String>> {
  /// The ids of the exercises the user most recently added to a workout or a
  /// program day, newest first and without repeats.
  ///
  /// Auto-disposed rather than `keepAlive`: only the exercise picker watches
  /// it, and re-reading each time the picker opens keeps it current without
  /// every add-exercise path having to invalidate it.
  RecentExerciseIdsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recentExerciseIdsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recentExerciseIdsHash();

  @$internal
  @override
  $FutureProviderElement<List<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<String>> create(Ref ref) {
    return recentExerciseIds(ref);
  }
}

String _$recentExerciseIdsHash() => r'76a8eb5e199c2d71801f49c2d2cfd3733c62a367';
