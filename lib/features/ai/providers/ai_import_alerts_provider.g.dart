// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_import_alerts_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The snackbars `AiImportJobAlerts` has shown, by job, so opening a job's
/// review some other way (Home's Review button) can take its alert away.

@ProviderFor(importAlertSnackBars)
final importAlertSnackBarsProvider = ImportAlertSnackBarsProvider._();

/// The snackbars `AiImportJobAlerts` has shown, by job, so opening a job's
/// review some other way (Home's Review button) can take its alert away.

final class ImportAlertSnackBarsProvider
    extends
        $FunctionalProvider<
          ImportAlertSnackBars,
          ImportAlertSnackBars,
          ImportAlertSnackBars
        >
    with $Provider<ImportAlertSnackBars> {
  /// The snackbars `AiImportJobAlerts` has shown, by job, so opening a job's
  /// review some other way (Home's Review button) can take its alert away.
  ImportAlertSnackBarsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'importAlertSnackBarsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$importAlertSnackBarsHash();

  @$internal
  @override
  $ProviderElement<ImportAlertSnackBars> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ImportAlertSnackBars create(Ref ref) {
    return importAlertSnackBars(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ImportAlertSnackBars value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ImportAlertSnackBars>(value),
    );
  }
}

String _$importAlertSnackBarsHash() =>
    r'f37cb9a7d28e87590113e73570e7ee7ba0da1d64';
