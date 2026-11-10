// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_import_jobs_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The signed-in user's open imports: processing, ready to review, or failed
/// and not yet dismissed. Newest first.
///
/// The job row is the only source of truth. Realtime ([aiImportJobWatchProvider])
/// and app resume only prompt a re-read of this provider; neither carries
/// state, because events missed while disconnected are never replayed.
///
/// Watches [currentAuthUserProvider] (which watches `authStateProvider`), so a
/// sign-out empties it and nothing crosses accounts.

@ProviderFor(AiImportJobsNotifier)
final aiImportJobsProvider = AiImportJobsNotifierProvider._();

/// The signed-in user's open imports: processing, ready to review, or failed
/// and not yet dismissed. Newest first.
///
/// The job row is the only source of truth. Realtime ([aiImportJobWatchProvider])
/// and app resume only prompt a re-read of this provider; neither carries
/// state, because events missed while disconnected are never replayed.
///
/// Watches [currentAuthUserProvider] (which watches `authStateProvider`), so a
/// sign-out empties it and nothing crosses accounts.
final class AiImportJobsNotifierProvider
    extends $AsyncNotifierProvider<AiImportJobsNotifier, List<AiImportJob>> {
  /// The signed-in user's open imports: processing, ready to review, or failed
  /// and not yet dismissed. Newest first.
  ///
  /// The job row is the only source of truth. Realtime ([aiImportJobWatchProvider])
  /// and app resume only prompt a re-read of this provider; neither carries
  /// state, because events missed while disconnected are never replayed.
  ///
  /// Watches [currentAuthUserProvider] (which watches `authStateProvider`), so a
  /// sign-out empties it and nothing crosses accounts.
  AiImportJobsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiImportJobsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiImportJobsNotifierHash();

  @$internal
  @override
  AiImportJobsNotifier create() => AiImportJobsNotifier();
}

String _$aiImportJobsNotifierHash() =>
    r'1793002ed67ba40a4a9ed006243c596c7b73530e';

/// The signed-in user's open imports: processing, ready to review, or failed
/// and not yet dismissed. Newest first.
///
/// The job row is the only source of truth. Realtime ([aiImportJobWatchProvider])
/// and app resume only prompt a re-read of this provider; neither carries
/// state, because events missed while disconnected are never replayed.
///
/// Watches [currentAuthUserProvider] (which watches `authStateProvider`), so a
/// sign-out empties it and nothing crosses accounts.

abstract class _$AiImportJobsNotifier
    extends $AsyncNotifier<List<AiImportJob>> {
  FutureOr<List<AiImportJob>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<AiImportJob>>, List<AiImportJob>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<AiImportJob>>, List<AiImportJob>>,
              AsyncValue<List<AiImportJob>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// The Realtime subscription, as a provider so tests can replace it.

@ProviderFor(aiImportJobSubscriber)
final aiImportJobSubscriberProvider = AiImportJobSubscriberProvider._();

/// The Realtime subscription, as a provider so tests can replace it.

final class AiImportJobSubscriberProvider
    extends
        $FunctionalProvider<
          AiImportJobSubscriber,
          AiImportJobSubscriber,
          AiImportJobSubscriber
        >
    with $Provider<AiImportJobSubscriber> {
  /// The Realtime subscription, as a provider so tests can replace it.
  AiImportJobSubscriberProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiImportJobSubscriberProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiImportJobSubscriberHash();

  @$internal
  @override
  $ProviderElement<AiImportJobSubscriber> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AiImportJobSubscriber create(Ref ref) {
    return aiImportJobSubscriber(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiImportJobSubscriber value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AiImportJobSubscriber>(value),
    );
  }
}

String _$aiImportJobSubscriberHash() =>
    r'a06d8032e6f38c14509e9539d9f7bf12fcb5a940';

/// Keeps [aiImportJobsProvider] current while an import is processing.
///
/// Subscribes to Realtime only while there's a live job to hear about, so a
/// user who never imports never holds a socket open. Also sets a timer for
/// the job's deadline: past it the job shows as failed, whether or not the
/// server has said anything. Watched for the app's lifetime from
/// `AiImportJobAlerts`.

@ProviderFor(aiImportJobWatch)
final aiImportJobWatchProvider = AiImportJobWatchProvider._();

/// Keeps [aiImportJobsProvider] current while an import is processing.
///
/// Subscribes to Realtime only while there's a live job to hear about, so a
/// user who never imports never holds a socket open. Also sets a timer for
/// the job's deadline: past it the job shows as failed, whether or not the
/// server has said anything. Watched for the app's lifetime from
/// `AiImportJobAlerts`.

final class AiImportJobWatchProvider
    extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// Keeps [aiImportJobsProvider] current while an import is processing.
  ///
  /// Subscribes to Realtime only while there's a live job to hear about, so a
  /// user who never imports never holds a socket open. Also sets a timer for
  /// the job's deadline: past it the job shows as failed, whether or not the
  /// server has said anything. Watched for the app's lifetime from
  /// `AiImportJobAlerts`.
  AiImportJobWatchProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiImportJobWatchProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiImportJobWatchHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return aiImportJobWatch(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$aiImportJobWatchHash() => r'61e0e1962307501c4d475f6f3c33781f4812956d';
