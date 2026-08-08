// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'program_instance_detail_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ProgramInstanceDetailNotifier)
final programInstanceDetailProvider = ProgramInstanceDetailNotifierFamily._();

final class ProgramInstanceDetailNotifierProvider
    extends
        $AsyncNotifierProvider<ProgramInstanceDetailNotifier, ProgramInstance> {
  ProgramInstanceDetailNotifierProvider._({
    required ProgramInstanceDetailNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'programInstanceDetailProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$programInstanceDetailNotifierHash();

  @override
  String toString() {
    return r'programInstanceDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ProgramInstanceDetailNotifier create() => ProgramInstanceDetailNotifier();

  @override
  bool operator ==(Object other) {
    return other is ProgramInstanceDetailNotifierProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$programInstanceDetailNotifierHash() =>
    r'2ae65a63b3e2f4a225fb732aa5cc1a8526219d45';

final class ProgramInstanceDetailNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          ProgramInstanceDetailNotifier,
          AsyncValue<ProgramInstance>,
          ProgramInstance,
          FutureOr<ProgramInstance>,
          String
        > {
  ProgramInstanceDetailNotifierFamily._()
    : super(
        retry: null,
        name: r'programInstanceDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  ProgramInstanceDetailNotifierProvider call(String instanceId) =>
      ProgramInstanceDetailNotifierProvider._(argument: instanceId, from: this);

  @override
  String toString() => r'programInstanceDetailProvider';
}

abstract class _$ProgramInstanceDetailNotifier
    extends $AsyncNotifier<ProgramInstance> {
  late final _$args = ref.$arg as String;
  String get instanceId => _$args;

  FutureOr<ProgramInstance> build(String instanceId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ProgramInstance>, ProgramInstance>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ProgramInstance>, ProgramInstance>,
              AsyncValue<ProgramInstance>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
