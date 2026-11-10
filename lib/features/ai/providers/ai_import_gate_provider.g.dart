// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_import_gate_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the import screen may offer an upload, checked each time it opens
/// with `ai_import_check()`: imports switched off, the one-time notice not yet
/// accepted (`consent_required`), an import already running, or a cap reached.
///
/// The server checks again on upload and on start, so this is only for the
/// user's benefit: they learn they can't import before choosing any files.

@ProviderFor(AiImportGateNotifier)
final aiImportGateProvider = AiImportGateNotifierProvider._();

/// Whether the import screen may offer an upload, checked each time it opens
/// with `ai_import_check()`: imports switched off, the one-time notice not yet
/// accepted (`consent_required`), an import already running, or a cap reached.
///
/// The server checks again on upload and on start, so this is only for the
/// user's benefit: they learn they can't import before choosing any files.
final class AiImportGateNotifierProvider
    extends $AsyncNotifierProvider<AiImportGateNotifier, AiImportCheck> {
  /// Whether the import screen may offer an upload, checked each time it opens
  /// with `ai_import_check()`: imports switched off, the one-time notice not yet
  /// accepted (`consent_required`), an import already running, or a cap reached.
  ///
  /// The server checks again on upload and on start, so this is only for the
  /// user's benefit: they learn they can't import before choosing any files.
  AiImportGateNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiImportGateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiImportGateNotifierHash();

  @$internal
  @override
  AiImportGateNotifier create() => AiImportGateNotifier();
}

String _$aiImportGateNotifierHash() =>
    r'dd0dc148b62dbbda67aef9bc9299c45efb18c5f0';

/// Whether the import screen may offer an upload, checked each time it opens
/// with `ai_import_check()`: imports switched off, the one-time notice not yet
/// accepted (`consent_required`), an import already running, or a cap reached.
///
/// The server checks again on upload and on start, so this is only for the
/// user's benefit: they learn they can't import before choosing any files.

abstract class _$AiImportGateNotifier extends $AsyncNotifier<AiImportCheck> {
  FutureOr<AiImportCheck> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<AiImportCheck>, AiImportCheck>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AiImportCheck>, AiImportCheck>,
              AsyncValue<AiImportCheck>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
