// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analytics_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's analytics sink. [NoopAnalytics] unless Firebase was initialized
/// (see `initFirebase()`), which keeps widget tests and Linux/Windows
/// desktop off Firebase without any override.

@ProviderFor(analytics)
final analyticsProvider = AnalyticsProvider._();

/// The app's analytics sink. [NoopAnalytics] unless Firebase was initialized
/// (see `initFirebase()`), which keeps widget tests and Linux/Windows
/// desktop off Firebase without any override.

final class AnalyticsProvider
    extends $FunctionalProvider<AppAnalytics, AppAnalytics, AppAnalytics>
    with $Provider<AppAnalytics> {
  /// The app's analytics sink. [NoopAnalytics] unless Firebase was initialized
  /// (see `initFirebase()`), which keeps widget tests and Linux/Windows
  /// desktop off Firebase without any override.
  AnalyticsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'analyticsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$analyticsHash();

  @$internal
  @override
  $ProviderElement<AppAnalytics> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppAnalytics create(Ref ref) {
    return analytics(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppAnalytics value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppAnalytics>(value),
    );
  }
}

String _$analyticsHash() => r'9e0e5513ddee645483a121a6ae3b7606fd6c1189';

/// Whether the user allows usage analytics: on unless they turn it off in
/// Profile. Saved on the device, like the sidebar state, since collection is
/// a setting of the analytics SDK on this device rather than of the account.
///
/// The choice is applied once it has loaded, never from the default, so a
/// user who opted out isn't briefly collected on launch. The native SDKs
/// also remember the last value across launches. `NomorexApp` watches this
/// so it loads at startup.

@ProviderFor(AnalyticsConsentNotifier)
final analyticsConsentProvider = AnalyticsConsentNotifierProvider._();

/// Whether the user allows usage analytics: on unless they turn it off in
/// Profile. Saved on the device, like the sidebar state, since collection is
/// a setting of the analytics SDK on this device rather than of the account.
///
/// The choice is applied once it has loaded, never from the default, so a
/// user who opted out isn't briefly collected on launch. The native SDKs
/// also remember the last value across launches. `NomorexApp` watches this
/// so it loads at startup.
final class AnalyticsConsentNotifierProvider
    extends $NotifierProvider<AnalyticsConsentNotifier, bool> {
  /// Whether the user allows usage analytics: on unless they turn it off in
  /// Profile. Saved on the device, like the sidebar state, since collection is
  /// a setting of the analytics SDK on this device rather than of the account.
  ///
  /// The choice is applied once it has loaded, never from the default, so a
  /// user who opted out isn't briefly collected on launch. The native SDKs
  /// also remember the last value across launches. `NomorexApp` watches this
  /// so it loads at startup.
  AnalyticsConsentNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'analyticsConsentProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$analyticsConsentNotifierHash();

  @$internal
  @override
  AnalyticsConsentNotifier create() => AnalyticsConsentNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$analyticsConsentNotifierHash() =>
    r'694acdeca6090d2d7949cbd0997fdde9ff135b11';

/// Whether the user allows usage analytics: on unless they turn it off in
/// Profile. Saved on the device, like the sidebar state, since collection is
/// a setting of the analytics SDK on this device rather than of the account.
///
/// The choice is applied once it has loaded, never from the default, so a
/// user who opted out isn't briefly collected on launch. The native SDKs
/// also remember the last value across launches. `NomorexApp` watches this
/// so it loads at startup.

abstract class _$AnalyticsConsentNotifier extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
