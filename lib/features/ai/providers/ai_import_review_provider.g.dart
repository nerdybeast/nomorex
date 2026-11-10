// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_import_review_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One import's review: the job and its result, plus the three ways out of a
/// review (accept, re-run as the other type, discard). Null when the job
/// doesn't exist or isn't the signed-in user's.

@ProviderFor(AiImportReviewNotifier)
final aiImportReviewProvider = AiImportReviewNotifierFamily._();

/// One import's review: the job and its result, plus the three ways out of a
/// review (accept, re-run as the other type, discard). Null when the job
/// doesn't exist or isn't the signed-in user's.
final class AiImportReviewNotifierProvider
    extends $AsyncNotifierProvider<AiImportReviewNotifier, AiImportReview?> {
  /// One import's review: the job and its result, plus the three ways out of a
  /// review (accept, re-run as the other type, discard). Null when the job
  /// doesn't exist or isn't the signed-in user's.
  AiImportReviewNotifierProvider._({
    required AiImportReviewNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'aiImportReviewProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$aiImportReviewNotifierHash();

  @override
  String toString() {
    return r'aiImportReviewProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  AiImportReviewNotifier create() => AiImportReviewNotifier();

  @override
  bool operator ==(Object other) {
    return other is AiImportReviewNotifierProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$aiImportReviewNotifierHash() =>
    r'dbd347740c6100dfa687657013df32b5623ce334';

/// One import's review: the job and its result, plus the three ways out of a
/// review (accept, re-run as the other type, discard). Null when the job
/// doesn't exist or isn't the signed-in user's.

final class AiImportReviewNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          AiImportReviewNotifier,
          AsyncValue<AiImportReview?>,
          AiImportReview?,
          FutureOr<AiImportReview?>,
          String
        > {
  AiImportReviewNotifierFamily._()
    : super(
        retry: null,
        name: r'aiImportReviewProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One import's review: the job and its result, plus the three ways out of a
  /// review (accept, re-run as the other type, discard). Null when the job
  /// doesn't exist or isn't the signed-in user's.

  AiImportReviewNotifierProvider call(String jobId) =>
      AiImportReviewNotifierProvider._(argument: jobId, from: this);

  @override
  String toString() => r'aiImportReviewProvider';
}

/// One import's review: the job and its result, plus the three ways out of a
/// review (accept, re-run as the other type, discard). Null when the job
/// doesn't exist or isn't the signed-in user's.

abstract class _$AiImportReviewNotifier
    extends $AsyncNotifier<AiImportReview?> {
  late final _$args = ref.$arg as String;
  String get jobId => _$args;

  FutureOr<AiImportReview?> build(String jobId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<AiImportReview?>, AiImportReview?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AiImportReview?>, AiImportReview?>,
              AsyncValue<AiImportReview?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
