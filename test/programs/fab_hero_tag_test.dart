import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/profile/providers/profile_provider.dart';
import 'package:nomorex/features/programs/models/program.dart';
import 'package:nomorex/features/programs/providers/program_detail_provider.dart';
import 'package:nomorex/features/programs/providers/programs_provider.dart';
import 'package:nomorex/features/programs/screens/program_edit_screen.dart';
import 'package:nomorex/features/programs/screens/programs_screen.dart';

// Same rule as test/workouts/fab_hero_tag_test.dart: the app shell always
// renders its own FAB, so any FAB on a screen inside the shell must declare
// a non-default heroTag or it collides with the shell FAB during route
// transitions.

class _EmptyProgramsNotifier extends ProgramsNotifier {
  @override
  Future<List<Program>> build() async => const [];
}

class _EmptyArchivedProgramsNotifier extends ArchivedProgramsNotifier {
  @override
  Future<List<Program>> build() async => const [];
}

class _StubProgramDetailNotifier extends ProgramDetailNotifier {
  _StubProgramDetailNotifier(this._program);
  final Program _program;
  @override
  Future<Program> build(String programId) async => _program;
}

void main() {
  testWidgets('ProgramsScreen FAB declares a non-default heroTag', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          programsProvider.overrideWith(() => _EmptyProgramsNotifier()),
          archivedProgramsProvider.overrideWith(() => _EmptyArchivedProgramsNotifier()),
        ],
        child: const MaterialApp(home: ProgramsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final fab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(fab.heroTag, 'programsNewFab');
  });

  testWidgets('ProgramEditScreen FAB declares a non-default heroTag', (tester) async {
    final program = Program(
      id: 'p1',
      userId: 'u1',
      name: 'ZT 6 Week Program',
      createdAt: DateTime(2026, 7, 5),
      updatedAt: DateTime(2026, 7, 5),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          programDetailProvider('p1').overrideWith(() => _StubProgramDetailNotifier(program)),
          unitPreferenceProvider.overrideWithValue('kg'),
        ],
        child: const MaterialApp(home: ProgramEditScreen(programId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    final fab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(fab.heroTag, 'editProgramFab');
  });
}
