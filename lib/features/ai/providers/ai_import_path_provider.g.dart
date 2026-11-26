// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_import_path_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The import path, or null while the settings or the hosted switch are still
/// loading. A key wins over the hosted alpha: it costs the project nothing,
/// and the lifter chose it.

@ProviderFor(aiImportPath)
final aiImportPathProvider = AiImportPathProvider._();

/// The import path, or null while the settings or the hosted switch are still
/// loading. A key wins over the hosted alpha: it costs the project nothing,
/// and the lifter chose it.

final class AiImportPathProvider
    extends $FunctionalProvider<ImportPath?, ImportPath?, ImportPath?>
    with $Provider<ImportPath?> {
  /// The import path, or null while the settings or the hosted switch are still
  /// loading. A key wins over the hosted alpha: it costs the project nothing,
  /// and the lifter chose it.
  AiImportPathProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiImportPathProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiImportPathHash();

  @$internal
  @override
  $ProviderElement<ImportPath?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ImportPath? create(Ref ref) {
    return aiImportPath(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ImportPath? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ImportPath?>(value),
    );
  }
}

String _$aiImportPathHash() => r'44607991466b0d5045a67a8a5d18808beadbbaa0';

/// Whether the import entry points show: the "New" menus, Home's getting
/// started and Programs' "Add a program". False while loading, so nothing
/// appears and then vanishes.

@ProviderFor(aiImportAvailable)
final aiImportAvailableProvider = AiImportAvailableProvider._();

/// Whether the import entry points show: the "New" menus, Home's getting
/// started and Programs' "Add a program". False while loading, so nothing
/// appears and then vanishes.

final class AiImportAvailableProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether the import entry points show: the "New" menus, Home's getting
  /// started and Programs' "Add a program". False while loading, so nothing
  /// appears and then vanishes.
  AiImportAvailableProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiImportAvailableProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiImportAvailableHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return aiImportAvailable(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$aiImportAvailableHash() => r'cdaa606a841b946d2f61b28262b9d6b8498c94e3';

/// The file limits for an import on [path]: the provider's own for a local
/// run (`importFileLimitsFor`), else the hosted row's.

@ProviderFor(aiImportIntakeLimits)
final aiImportIntakeLimitsProvider = AiImportIntakeLimitsProvider._();

/// The file limits for an import on [path]: the provider's own for a local
/// run (`importFileLimitsFor`), else the hosted row's.

final class AiImportIntakeLimitsProvider
    extends
        $FunctionalProvider<
          AsyncValue<AiImportLimits>,
          AiImportLimits,
          FutureOr<AiImportLimits>
        >
    with $FutureModifier<AiImportLimits>, $FutureProvider<AiImportLimits> {
  /// The file limits for an import on [path]: the provider's own for a local
  /// run (`importFileLimitsFor`), else the hosted row's.
  AiImportIntakeLimitsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiImportIntakeLimitsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiImportIntakeLimitsHash();

  @$internal
  @override
  $FutureProviderElement<AiImportLimits> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AiImportLimits> create(Ref ref) {
    return aiImportIntakeLimits(ref);
  }
}

String _$aiImportIntakeLimitsHash() =>
    r'ac8d1b0f8238c74be17d23a68e298eccf1edd853';

/// The providers whose one-time notice this device has shown and the lifter
/// accepted. Stored on the device, like the key: it's about sending files
/// from here to that provider, and is separate from the hosted alpha's
/// `ai_import_consents`.

@ProviderFor(AiImportNoticeNotifier)
final aiImportNoticeProvider = AiImportNoticeNotifierProvider._();

/// The providers whose one-time notice this device has shown and the lifter
/// accepted. Stored on the device, like the key: it's about sending files
/// from here to that provider, and is separate from the hosted alpha's
/// `ai_import_consents`.
final class AiImportNoticeNotifierProvider
    extends
        $AsyncNotifierProvider<AiImportNoticeNotifier, Set<CloudAiProvider>> {
  /// The providers whose one-time notice this device has shown and the lifter
  /// accepted. Stored on the device, like the key: it's about sending files
  /// from here to that provider, and is separate from the hosted alpha's
  /// `ai_import_consents`.
  AiImportNoticeNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiImportNoticeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiImportNoticeNotifierHash();

  @$internal
  @override
  AiImportNoticeNotifier create() => AiImportNoticeNotifier();
}

String _$aiImportNoticeNotifierHash() =>
    r'4ba90e81e4b5eb4df7f60522bdfae6558547974c';

/// The providers whose one-time notice this device has shown and the lifter
/// accepted. Stored on the device, like the key: it's about sending files
/// from here to that provider, and is separate from the hosted alpha's
/// `ai_import_consents`.

abstract class _$AiImportNoticeNotifier
    extends $AsyncNotifier<Set<CloudAiProvider>> {
  FutureOr<Set<CloudAiProvider>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<Set<CloudAiProvider>>, Set<CloudAiProvider>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<Set<CloudAiProvider>>,
                Set<CloudAiProvider>
              >,
              AsyncValue<Set<CloudAiProvider>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
