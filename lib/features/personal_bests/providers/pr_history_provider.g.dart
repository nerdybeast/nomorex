// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pr_history_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every PR entry logged for one exercise, sorted by date descending.

@ProviderFor(prHistory)
final prHistoryProvider = PrHistoryFamily._();

/// Every PR entry logged for one exercise, sorted by date descending.

final class PrHistoryProvider
    extends
        $FunctionalProvider<
          List<PersonalBest>,
          List<PersonalBest>,
          List<PersonalBest>
        >
    with $Provider<List<PersonalBest>> {
  /// Every PR entry logged for one exercise, sorted by date descending.
  PrHistoryProvider._({
    required PrHistoryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'prHistoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$prHistoryHash();

  @override
  String toString() {
    return r'prHistoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<List<PersonalBest>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<PersonalBest> create(Ref ref) {
    final argument = this.argument as String;
    return prHistory(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<PersonalBest> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<PersonalBest>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PrHistoryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$prHistoryHash() => r'229d7ceb0ef834812289ed92776655a4b834a3e2';

/// Every PR entry logged for one exercise, sorted by date descending.

final class PrHistoryFamily extends $Family
    with $FunctionalFamilyOverride<List<PersonalBest>, String> {
  PrHistoryFamily._()
    : super(
        retry: null,
        name: r'prHistoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Every PR entry logged for one exercise, sorted by date descending.

  PrHistoryProvider call(String exerciseId) =>
      PrHistoryProvider._(argument: exerciseId, from: this);

  @override
  String toString() => r'prHistoryProvider';
}
