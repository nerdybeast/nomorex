// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'program_detail_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ProgramDetailNotifier)
final programDetailProvider = ProgramDetailNotifierFamily._();

final class ProgramDetailNotifierProvider
    extends $AsyncNotifierProvider<ProgramDetailNotifier, Program> {
  ProgramDetailNotifierProvider._({
    required ProgramDetailNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'programDetailProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$programDetailNotifierHash();

  @override
  String toString() {
    return r'programDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ProgramDetailNotifier create() => ProgramDetailNotifier();

  @override
  bool operator ==(Object other) {
    return other is ProgramDetailNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$programDetailNotifierHash() =>
    r'648120ed3ee2678891a412d31e1de6d1b80179c9';

final class ProgramDetailNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          ProgramDetailNotifier,
          AsyncValue<Program>,
          Program,
          FutureOr<Program>,
          String
        > {
  ProgramDetailNotifierFamily._()
    : super(
        retry: null,
        name: r'programDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  ProgramDetailNotifierProvider call(String programId) =>
      ProgramDetailNotifierProvider._(argument: programId, from: this);

  @override
  String toString() => r'programDetailProvider';
}

abstract class _$ProgramDetailNotifier extends $AsyncNotifier<Program> {
  late final _$args = ref.$arg as String;
  String get programId => _$args;

  FutureOr<Program> build(String programId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Program>, Program>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Program>, Program>,
              AsyncValue<Program>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
