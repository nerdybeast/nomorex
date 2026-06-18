// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Returns the 5 most recently updated PRs for the dashboard.
/// personalBestsProvider is already ordered by updated_at desc.

@ProviderFor(dashboardPrs)
final dashboardPrsProvider = DashboardPrsProvider._();

/// Returns the 5 most recently updated PRs for the dashboard.
/// personalBestsProvider is already ordered by updated_at desc.

final class DashboardPrsProvider
    extends
        $FunctionalProvider<
          List<PersonalBest>,
          List<PersonalBest>,
          List<PersonalBest>
        >
    with $Provider<List<PersonalBest>> {
  /// Returns the 5 most recently updated PRs for the dashboard.
  /// personalBestsProvider is already ordered by updated_at desc.
  DashboardPrsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dashboardPrsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dashboardPrsHash();

  @$internal
  @override
  $ProviderElement<List<PersonalBest>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<PersonalBest> create(Ref ref) {
    return dashboardPrs(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<PersonalBest> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<PersonalBest>>(value),
    );
  }
}

String _$dashboardPrsHash() => r'b433bdc4f0f545683e3b4a52186bea61fafa6ac3';
