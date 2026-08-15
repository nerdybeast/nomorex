// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exercises_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ExercisesNotifier)
final exercisesProvider = ExercisesNotifierProvider._();

final class ExercisesNotifierProvider
    extends $AsyncNotifierProvider<ExercisesNotifier, List<Exercise>> {
  ExercisesNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'exercisesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$exercisesNotifierHash();

  @$internal
  @override
  ExercisesNotifier create() => ExercisesNotifier();
}

String _$exercisesNotifierHash() => r'77b534aac8cb2eeadf66115a82a92b0ec9242cb3';

abstract class _$ExercisesNotifier extends $AsyncNotifier<List<Exercise>> {
  FutureOr<List<Exercise>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Exercise>>, List<Exercise>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Exercise>>, List<Exercise>>,
              AsyncValue<List<Exercise>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
