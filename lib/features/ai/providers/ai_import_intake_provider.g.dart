// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_import_intake_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(importFilePicker)
final importFilePickerProvider = ImportFilePickerProvider._();

final class ImportFilePickerProvider
    extends
        $FunctionalProvider<
          ImportFilePicker,
          ImportFilePicker,
          ImportFilePicker
        >
    with $Provider<ImportFilePicker> {
  ImportFilePickerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'importFilePickerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$importFilePickerHash();

  @$internal
  @override
  $ProviderElement<ImportFilePicker> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ImportFilePicker create(Ref ref) {
    return importFilePicker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ImportFilePicker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ImportFilePicker>(value),
    );
  }
}

String _$importFilePickerHash() => r'575b8c49496c8a70a737abdf85c3d5a8c7a940e0';

/// The file caps, read so files can be refused before upload. Not user data,
/// but re-read on sign-in anyway, since the row is only visible to
/// authenticated users.

@ProviderFor(aiImportLimits)
final aiImportLimitsProvider = AiImportLimitsProvider._();

/// The file caps, read so files can be refused before upload. Not user data,
/// but re-read on sign-in anyway, since the row is only visible to
/// authenticated users.

final class AiImportLimitsProvider
    extends
        $FunctionalProvider<
          AsyncValue<AiImportLimits>,
          AiImportLimits,
          FutureOr<AiImportLimits>
        >
    with $FutureModifier<AiImportLimits>, $FutureProvider<AiImportLimits> {
  /// The file caps, read so files can be refused before upload. Not user data,
  /// but re-read on sign-in anyway, since the row is only visible to
  /// authenticated users.
  AiImportLimitsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiImportLimitsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiImportLimitsHash();

  @$internal
  @override
  $FutureProviderElement<AiImportLimits> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AiImportLimits> create(Ref ref) {
    return aiImportLimits(ref);
  }
}

String _$aiImportLimitsHash() => r'778ad6e842b89cfbb71f222a38ba8249ddbdc412';

/// Picks, checks and uploads the files for one import, then starts it.
///
/// Every check here is for the user's benefit: it names the limit before an
/// upload is wasted. The server enforces the same rules on the bytes (#82),
/// and the bucket's insert policy runs `ai_import_check()` on every file.

@ProviderFor(AiImportIntakeNotifier)
final aiImportIntakeProvider = AiImportIntakeNotifierProvider._();

/// Picks, checks and uploads the files for one import, then starts it.
///
/// Every check here is for the user's benefit: it names the limit before an
/// upload is wasted. The server enforces the same rules on the bytes (#82),
/// and the bucket's insert policy runs `ai_import_check()` on every file.
final class AiImportIntakeNotifierProvider
    extends $NotifierProvider<AiImportIntakeNotifier, ImportIntakeState> {
  /// Picks, checks and uploads the files for one import, then starts it.
  ///
  /// Every check here is for the user's benefit: it names the limit before an
  /// upload is wasted. The server enforces the same rules on the bytes (#82),
  /// and the bucket's insert policy runs `ai_import_check()` on every file.
  AiImportIntakeNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiImportIntakeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiImportIntakeNotifierHash();

  @$internal
  @override
  AiImportIntakeNotifier create() => AiImportIntakeNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ImportIntakeState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ImportIntakeState>(value),
    );
  }
}

String _$aiImportIntakeNotifierHash() =>
    r'1fcdf6eccaa1e0ba239fb9d5fd7e861165d0f32d';

/// Picks, checks and uploads the files for one import, then starts it.
///
/// Every check here is for the user's benefit: it names the limit before an
/// upload is wasted. The server enforces the same rules on the bytes (#82),
/// and the bucket's insert policy runs `ai_import_check()` on every file.

abstract class _$AiImportIntakeNotifier extends $Notifier<ImportIntakeState> {
  ImportIntakeState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ImportIntakeState, ImportIntakeState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ImportIntakeState, ImportIntakeState>,
              ImportIntakeState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
