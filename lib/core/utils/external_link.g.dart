// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'external_link.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Opens a web page outside the app (the browser, or an in-app browser tab
/// where the platform prefers one). Returns false when nothing could open it.
///
/// A provider so widget tests can override it: url_launcher goes through a
/// platform channel that tests don't have.

@ProviderFor(externalLinkOpener)
final externalLinkOpenerProvider = ExternalLinkOpenerProvider._();

/// Opens a web page outside the app (the browser, or an in-app browser tab
/// where the platform prefers one). Returns false when nothing could open it.
///
/// A provider so widget tests can override it: url_launcher goes through a
/// platform channel that tests don't have.

final class ExternalLinkOpenerProvider
    extends
        $FunctionalProvider<
          Future<bool> Function(Uri),
          Future<bool> Function(Uri),
          Future<bool> Function(Uri)
        >
    with $Provider<Future<bool> Function(Uri)> {
  /// Opens a web page outside the app (the browser, or an in-app browser tab
  /// where the platform prefers one). Returns false when nothing could open it.
  ///
  /// A provider so widget tests can override it: url_launcher goes through a
  /// platform channel that tests don't have.
  ExternalLinkOpenerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'externalLinkOpenerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$externalLinkOpenerHash();

  @$internal
  @override
  $ProviderElement<Future<bool> Function(Uri)> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Future<bool> Function(Uri) create(Ref ref) {
    return externalLinkOpener(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Future<bool> Function(Uri) value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Future<bool> Function(Uri)>(value),
    );
  }
}

String _$externalLinkOpenerHash() =>
    r'b2159c2551461dde34b8f8a3fa0d95f097271112';
