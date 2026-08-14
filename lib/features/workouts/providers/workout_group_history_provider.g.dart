// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_group_history_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether this workout-group has at least one finished completion —
/// derived from [finishedWorkoutsProvider]'s already-loaded list, mirroring
/// [prHistoryProvider]'s pattern. Drives whether a not-started workout's
/// detail screen offers "Do This Workout Again" instead of plain
/// "Start Workout".

@ProviderFor(groupHasFinishedHistory)
final groupHasFinishedHistoryProvider = GroupHasFinishedHistoryFamily._();

/// Whether this workout-group has at least one finished completion —
/// derived from [finishedWorkoutsProvider]'s already-loaded list, mirroring
/// [prHistoryProvider]'s pattern. Drives whether a not-started workout's
/// detail screen offers "Do This Workout Again" instead of plain
/// "Start Workout".

final class GroupHasFinishedHistoryProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether this workout-group has at least one finished completion —
  /// derived from [finishedWorkoutsProvider]'s already-loaded list, mirroring
  /// [prHistoryProvider]'s pattern. Drives whether a not-started workout's
  /// detail screen offers "Do This Workout Again" instead of plain
  /// "Start Workout".
  GroupHasFinishedHistoryProvider._({
    required GroupHasFinishedHistoryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'groupHasFinishedHistoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$groupHasFinishedHistoryHash();

  @override
  String toString() {
    return r'groupHasFinishedHistoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    final argument = this.argument as String;
    return groupHasFinishedHistory(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is GroupHasFinishedHistoryProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$groupHasFinishedHistoryHash() =>
    r'b84990531004f0612d5ac928383a5b994f2f1a80';

/// Whether this workout-group has at least one finished completion —
/// derived from [finishedWorkoutsProvider]'s already-loaded list, mirroring
/// [prHistoryProvider]'s pattern. Drives whether a not-started workout's
/// detail screen offers "Do This Workout Again" instead of plain
/// "Start Workout".

final class GroupHasFinishedHistoryFamily extends $Family
    with $FunctionalFamilyOverride<bool, String> {
  GroupHasFinishedHistoryFamily._()
    : super(
        retry: null,
        name: r'groupHasFinishedHistoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Whether this workout-group has at least one finished completion —
  /// derived from [finishedWorkoutsProvider]'s already-loaded list, mirroring
  /// [prHistoryProvider]'s pattern. Drives whether a not-started workout's
  /// detail screen offers "Do This Workout Again" instead of plain
  /// "Start Workout".

  GroupHasFinishedHistoryProvider call(String groupId) =>
      GroupHasFinishedHistoryProvider._(argument: groupId, from: this);

  @override
  String toString() => r'groupHasFinishedHistoryProvider';
}
