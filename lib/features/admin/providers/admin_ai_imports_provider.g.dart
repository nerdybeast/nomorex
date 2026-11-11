// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_ai_imports_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The AI import on/off switch on the admin screen. The value itself is read
/// from [aiImportLimitsProvider]; this only changes it. Loading while a change
/// is being saved.

@ProviderFor(AdminAiImportsNotifier)
final adminAiImportsProvider = AdminAiImportsNotifierProvider._();

/// The AI import on/off switch on the admin screen. The value itself is read
/// from [aiImportLimitsProvider]; this only changes it. Loading while a change
/// is being saved.
final class AdminAiImportsNotifierProvider
    extends $AsyncNotifierProvider<AdminAiImportsNotifier, void> {
  /// The AI import on/off switch on the admin screen. The value itself is read
  /// from [aiImportLimitsProvider]; this only changes it. Loading while a change
  /// is being saved.
  AdminAiImportsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'adminAiImportsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$adminAiImportsNotifierHash();

  @$internal
  @override
  AdminAiImportsNotifier create() => AdminAiImportsNotifier();
}

String _$adminAiImportsNotifierHash() =>
    r'c42125d589f2d80b45e04a7cff9cd5cba07ca2c1';

/// The AI import on/off switch on the admin screen. The value itself is read
/// from [aiImportLimitsProvider]; this only changes it. Loading while a change
/// is being saved.

abstract class _$AdminAiImportsNotifier extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
