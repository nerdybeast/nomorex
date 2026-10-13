import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/core/utils/copy_errors.dart';
import 'package:nomorex/features/exercises/models/exercise.dart';
import 'package:nomorex/features/exercises/providers/exercises_provider.dart';
import 'package:nomorex/features/profile/providers/profile_provider.dart';
import 'package:nomorex/features/programs/models/program.dart';
import 'package:nomorex/features/programs/models/program_instance.dart';
import 'package:nomorex/features/programs/providers/program_detail_provider.dart';
import 'package:nomorex/features/programs/providers/program_instance_detail_provider.dart';
import 'package:nomorex/features/programs/providers/program_instance_workouts_provider.dart';
import 'package:nomorex/features/programs/providers/program_instances_list_provider.dart';
import 'package:nomorex/features/programs/providers/programs_provider.dart';
import 'package:nomorex/features/programs/screens/program_detail_screen.dart';
import 'package:nomorex/features/programs/screens/program_edit_screen.dart';
import 'package:nomorex/features/programs/screens/program_instance_detail_screen.dart';
import 'package:nomorex/features/programs/screens/programs_screen.dart';

class _StubProgramsNotifier extends ProgramsNotifier {
  _StubProgramsNotifier(this._programs);
  final List<Program> _programs;
  @override
  Future<List<Program>> build() async => _programs;
}

class _EmptyProgramInstancesNotifier extends CurrentProgramInstancesNotifier {
  @override
  Future<List<ProgramInstance>> build() async => [];
}

class _StubProgramDetailNotifier extends ProgramDetailNotifier {
  _StubProgramDetailNotifier(this._program, {this.onUpdateVisibility});
  final Program _program;
  final void Function(bool)? onUpdateVisibility;
  @override
  Future<Program> build(String programId) async => _program;
  @override
  Future<void> updateVisibility(bool isPublic) async => onUpdateVisibility?.call(isPublic);
}

class _StubInstanceNotifier extends ProgramInstanceDetailNotifier {
  @override
  Future<ProgramInstance> build(String instanceId) async => ProgramInstance(
        id: 'run-1',
        programId: 'p1',
        userId: 'viewer',
        startedAt: DateTime(2026, 10, 12),
        status: 'active',
        programName: "B's Block",
      );
}

class _EmptyInstanceWorkoutsNotifier extends ProgramInstanceWorkoutsNotifier {
  @override
  Future<Map<String, String>> build(String instanceId) async => const {};
}

class _StubExercisesNotifier extends ExercisesNotifier {
  @override
  Future<List<Exercise>> build() async => const [];
}

Program _copiedProgram({bool isCopy = true}) => Program(
      id: 'p1',
      userId: 'viewer',
      name: "B's Block",
      createdAt: DateTime(2026, 10, 12),
      updatedAt: DateTime(2026, 10, 12),
      isCopy: isCopy,
      copiedFromUserId: isCopy ? 'author' : null,
      copiedFromDisplayName: isCopy ? 'BeastModeB' : null,
      copiedFromProgramId: isCopy ? 'p0' : null,
    );

List<Override> _detailOverrides(Program program, {void Function(bool)? onUpdateVisibility}) => [
      programDetailProvider('p1').overrideWith(
        () => _StubProgramDetailNotifier(program, onUpdateVisibility: onUpdateVisibility),
      ),
      currentProgramInstancesProvider.overrideWith(() => _EmptyProgramInstancesNotifier()),
      exercisesProvider.overrideWith(() => _StubExercisesNotifier()),
      unitPreferenceProvider.overrideWithValue('kg'),
    ];

void main() {
  testWidgets('a copied program is badged on its Programs list card', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          programsProvider.overrideWith(() => _StubProgramsNotifier([_copiedProgram()])),
          currentProgramInstancesProvider.overrideWith(() => _EmptyProgramInstancesNotifier()),
        ],
        child: const MaterialApp(home: ProgramsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('copied_from_badge')), findsOneWidget);
    expect(find.text('Copied from BeastModeB'), findsOneWidget);
  });

  testWidgets('a program the user wrote has no badge', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          programsProvider.overrideWith(
            () => _StubProgramsNotifier([_copiedProgram(isCopy: false)]),
          ),
          currentProgramInstancesProvider.overrideWith(() => _EmptyProgramInstancesNotifier()),
        ],
        child: const MaterialApp(home: ProgramsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Copied from'), findsNothing);
  });

  testWidgets('a copied program is badged on its detail screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _detailOverrides(_copiedProgram()),
        child: const MaterialApp(home: ProgramDetailScreen(programId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Copied from BeastModeB'), findsOneWidget);
  });

  testWidgets('editing a copy: badge shown, Public switch disabled with the reason',
      (tester) async {
    var toggled = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: _detailOverrides(_copiedProgram(), onUpdateVisibility: (_) => toggled = true),
        child: const MaterialApp(home: ProgramEditScreen(programId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Copied from BeastModeB'), findsOneWidget);
    final publicSwitch = tester.widget<Switch>(find.byType(Switch));
    expect(publicSwitch.onChanged, isNull);
    expect(find.text(kCopyNotShareableMessage), findsOneWidget);

    await tester.tap(find.byType(Switch), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(toggled, isFalse);
  });

  testWidgets('a run of a copied program is badged (FR-008a)', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._detailOverrides(_copiedProgram()),
          programInstanceDetailProvider('run-1').overrideWith(() => _StubInstanceNotifier()),
          programInstanceWorkoutsProvider('run-1')
              .overrideWith(() => _EmptyInstanceWorkoutsNotifier()),
        ],
        child: const MaterialApp(home: ProgramInstanceDetailScreen(instanceId: 'run-1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('copied_from_badge')), findsOneWidget);
    expect(find.text('Copied from BeastModeB'), findsOneWidget);
  });
}
