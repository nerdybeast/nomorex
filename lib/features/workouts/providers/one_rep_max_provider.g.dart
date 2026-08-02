// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'one_rep_max_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// exerciseId -> the user's heaviest recorded 1-rep PR (kg) for that lift.

@ProviderFor(oneRepMax)
final oneRepMaxProvider = OneRepMaxProvider._();

/// exerciseId -> the user's heaviest recorded 1-rep PR (kg) for that lift.

final class OneRepMaxProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, double>>,
          Map<String, double>,
          FutureOr<Map<String, double>>
        >
    with
        $FutureModifier<Map<String, double>>,
        $FutureProvider<Map<String, double>> {
  /// exerciseId -> the user's heaviest recorded 1-rep PR (kg) for that lift.
  OneRepMaxProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'oneRepMaxProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$oneRepMaxHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, double>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, double>> create(Ref ref) {
    return oneRepMax(ref);
  }
}

String _$oneRepMaxHash() => r'f6d94a4b3422e9cc76a5d19ebdd73e9695e53e5d';
