// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'my_prs_grouped_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Groups all PRs by exercise name, sorted alphabetically.
/// Each group's entries are sorted by date descending.

@ProviderFor(myPrsGrouped)
final myPrsGroupedProvider = MyPrsGroupedProvider._();

/// Groups all PRs by exercise name, sorted alphabetically.
/// Each group's entries are sorted by date descending.

final class MyPrsGroupedProvider
    extends
        $FunctionalProvider<
          Map<String, List<PersonalBest>>,
          Map<String, List<PersonalBest>>,
          Map<String, List<PersonalBest>>
        >
    with $Provider<Map<String, List<PersonalBest>>> {
  /// Groups all PRs by exercise name, sorted alphabetically.
  /// Each group's entries are sorted by date descending.
  MyPrsGroupedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myPrsGroupedProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myPrsGroupedHash();

  @$internal
  @override
  $ProviderElement<Map<String, List<PersonalBest>>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Map<String, List<PersonalBest>> create(Ref ref) {
    return myPrsGrouped(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, List<PersonalBest>> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, List<PersonalBest>>>(
        value,
      ),
    );
  }
}

String _$myPrsGroupedHash() => r'20b2f4be9d101453f6f4d89eff18d47d6a89d1ee';
