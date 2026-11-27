// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'genkit_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's Genkit instance, with the plugin for the chosen cloud provider
/// when its key is saved, and the on-device model where it's ready: Apple
/// Intelligence on iOS and macOS (Stage 7); Gemini Nano and Chrome's join in
/// Stage 8.
///
/// Rebuilt whenever the provider or a key changes, because plugins take the
/// key when they're created. Widget tests override this with a Genkit that
/// holds a fake model (`ai.defineModel`).

@ProviderFor(genkit)
final genkitProvider = GenkitProvider._();

/// The app's Genkit instance, with the plugin for the chosen cloud provider
/// when its key is saved, and the on-device model where it's ready: Apple
/// Intelligence on iOS and macOS (Stage 7); Gemini Nano and Chrome's join in
/// Stage 8.
///
/// Rebuilt whenever the provider or a key changes, because plugins take the
/// key when they're created. Widget tests override this with a Genkit that
/// holds a fake model (`ai.defineModel`).

final class GenkitProvider
    extends $FunctionalProvider<AsyncValue<Genkit>, Genkit, FutureOr<Genkit>>
    with $FutureModifier<Genkit>, $FutureProvider<Genkit> {
  /// The app's Genkit instance, with the plugin for the chosen cloud provider
  /// when its key is saved, and the on-device model where it's ready: Apple
  /// Intelligence on iOS and macOS (Stage 7); Gemini Nano and Chrome's join in
  /// Stage 8.
  ///
  /// Rebuilt whenever the provider or a key changes, because plugins take the
  /// key when they're created. Widget tests override this with a Genkit that
  /// holds a fake model (`ai.defineModel`).
  GenkitProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'genkitProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$genkitHash();

  @$internal
  @override
  $FutureProviderElement<Genkit> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Genkit> create(Ref ref) {
    return genkit(ref);
  }
}

String _$genkitHash() => r'6337614e87900effa148b2f60fcdbc883a802881';
