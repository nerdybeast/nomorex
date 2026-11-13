// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sidebar_collapse_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The sidebar's collapsed state. Saved on the device rather than in the
/// profile: it's about this screen, not the person.
///
/// Starts from the defaults and replaces them once the saved choice loads. If
/// the device can't store it (or in widget tests, where there's no platform
/// plugin), the defaults simply stay.

@ProviderFor(SidebarCollapseNotifier)
final sidebarCollapseProvider = SidebarCollapseNotifierProvider._();

/// The sidebar's collapsed state. Saved on the device rather than in the
/// profile: it's about this screen, not the person.
///
/// Starts from the defaults and replaces them once the saved choice loads. If
/// the device can't store it (or in widget tests, where there's no platform
/// plugin), the defaults simply stay.
final class SidebarCollapseNotifierProvider
    extends $NotifierProvider<SidebarCollapseNotifier, SidebarCollapseState> {
  /// The sidebar's collapsed state. Saved on the device rather than in the
  /// profile: it's about this screen, not the person.
  ///
  /// Starts from the defaults and replaces them once the saved choice loads. If
  /// the device can't store it (or in widget tests, where there's no platform
  /// plugin), the defaults simply stay.
  SidebarCollapseNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sidebarCollapseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sidebarCollapseNotifierHash();

  @$internal
  @override
  SidebarCollapseNotifier create() => SidebarCollapseNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SidebarCollapseState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SidebarCollapseState>(value),
    );
  }
}

String _$sidebarCollapseNotifierHash() =>
    r'498838430dacc33897fa0ec7c6bd4497ada7b71c';

/// The sidebar's collapsed state. Saved on the device rather than in the
/// profile: it's about this screen, not the person.
///
/// Starts from the defaults and replaces them once the saved choice loads. If
/// the device can't store it (or in widget tests, where there's no platform
/// plugin), the defaults simply stay.

abstract class _$SidebarCollapseNotifier
    extends $Notifier<SidebarCollapseState> {
  SidebarCollapseState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<SidebarCollapseState, SidebarCollapseState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SidebarCollapseState, SidebarCollapseState>,
              SidebarCollapseState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
