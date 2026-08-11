// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'personal_bests_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PersonalBestsNotifier)
final personalBestsProvider = PersonalBestsNotifierProvider._();

final class PersonalBestsNotifierProvider
    extends $AsyncNotifierProvider<PersonalBestsNotifier, List<PersonalBest>> {
  PersonalBestsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'personalBestsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$personalBestsNotifierHash();

  @$internal
  @override
  PersonalBestsNotifier create() => PersonalBestsNotifier();
}

String _$personalBestsNotifierHash() =>
    r'74d345bc1ce6d69accbca3c05e9bf11bbf70ca59';

abstract class _$PersonalBestsNotifier
    extends $AsyncNotifier<List<PersonalBest>> {
  FutureOr<List<PersonalBest>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<PersonalBest>>, List<PersonalBest>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<PersonalBest>>, List<PersonalBest>>,
              AsyncValue<List<PersonalBest>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
