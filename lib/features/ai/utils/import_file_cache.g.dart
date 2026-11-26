// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'import_file_cache.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(importFileCache)
final importFileCacheProvider = ImportFileCacheProvider._();

final class ImportFileCacheProvider
    extends
        $FunctionalProvider<ImportFileCache, ImportFileCache, ImportFileCache>
    with $Provider<ImportFileCache> {
  ImportFileCacheProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'importFileCacheProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$importFileCacheHash();

  @$internal
  @override
  $ProviderElement<ImportFileCache> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ImportFileCache create(Ref ref) {
    return importFileCache(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ImportFileCache value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ImportFileCache>(value),
    );
  }
}

String _$importFileCacheHash() => r'419642e0440c135150b27d68d03bdef165bc7c4e';

/// One import's cached files, for the review screen's re-run.

@ProviderFor(cachedImport)
final cachedImportProvider = CachedImportFamily._();

/// One import's cached files, for the review screen's re-run.

final class CachedImportProvider
    extends
        $FunctionalProvider<
          AsyncValue<CachedImport?>,
          CachedImport?,
          FutureOr<CachedImport?>
        >
    with $FutureModifier<CachedImport?>, $FutureProvider<CachedImport?> {
  /// One import's cached files, for the review screen's re-run.
  CachedImportProvider._({
    required CachedImportFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'cachedImportProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$cachedImportHash();

  @override
  String toString() {
    return r'cachedImportProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<CachedImport?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CachedImport?> create(Ref ref) {
    final argument = this.argument as String;
    return cachedImport(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CachedImportProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$cachedImportHash() => r'c1fa585a72814ebd47389c6dfe6456c67fd5fc22';

/// One import's cached files, for the review screen's re-run.

final class CachedImportFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<CachedImport?>, String> {
  CachedImportFamily._()
    : super(
        retry: null,
        name: r'cachedImportProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One import's cached files, for the review screen's re-run.

  CachedImportProvider call(String importId) =>
      CachedImportProvider._(argument: importId, from: this);

  @override
  String toString() => r'cachedImportProvider';
}
