// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'training_view_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The Training view used last, so the Training tab reopens on it, across
/// launches too. Starts at Programs and is saved on the device.
///
/// The saved view loads asynchronously; [lastUsed] waits for it, which is what
/// the bare Training route's redirect uses. If the device can't store it (or
/// in widget tests, where there's no platform plugin), it stays at Programs. Doesn't depend on the signed-in user: it's a device preference,
/// like the sidebar's collapsed state.

@ProviderFor(TrainingViewNotifier)
final trainingViewProvider = TrainingViewNotifierProvider._();

/// The Training view used last, so the Training tab reopens on it, across
/// launches too. Starts at Programs and is saved on the device.
///
/// The saved view loads asynchronously; [lastUsed] waits for it, which is what
/// the bare Training route's redirect uses. If the device can't store it (or
/// in widget tests, where there's no platform plugin), it stays at Programs. Doesn't depend on the signed-in user: it's a device preference,
/// like the sidebar's collapsed state.
final class TrainingViewNotifierProvider
    extends $NotifierProvider<TrainingViewNotifier, TrainingView> {
  /// The Training view used last, so the Training tab reopens on it, across
  /// launches too. Starts at Programs and is saved on the device.
  ///
  /// The saved view loads asynchronously; [lastUsed] waits for it, which is what
  /// the bare Training route's redirect uses. If the device can't store it (or
  /// in widget tests, where there's no platform plugin), it stays at Programs. Doesn't depend on the signed-in user: it's a device preference,
  /// like the sidebar's collapsed state.
  TrainingViewNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trainingViewProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trainingViewNotifierHash();

  @$internal
  @override
  TrainingViewNotifier create() => TrainingViewNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TrainingView value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TrainingView>(value),
    );
  }
}

String _$trainingViewNotifierHash() =>
    r'2176c56d5cd7ae6b66add78275b23444eb14e6ea';

/// The Training view used last, so the Training tab reopens on it, across
/// launches too. Starts at Programs and is saved on the device.
///
/// The saved view loads asynchronously; [lastUsed] waits for it, which is what
/// the bare Training route's redirect uses. If the device can't store it (or
/// in widget tests, where there's no platform plugin), it stays at Programs. Doesn't depend on the signed-in user: it's a device preference,
/// like the sidebar's collapsed state.

abstract class _$TrainingViewNotifier extends $Notifier<TrainingView> {
  TrainingView build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<TrainingView, TrainingView>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TrainingView, TrainingView>,
              TrainingView,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
