import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/programs/models/program.dart';
import 'package:nomorex/features/programs/providers/programs_provider.dart';
import 'package:nomorex/features/programs/screens/new_program_screen.dart';

class _EmptyProgramsNotifier extends ProgramsNotifier {
  @override
  Future<List<Program>> build() async => const [];
}

void main() {
  testWidgets('shows example names and the add-weeks hint under Save',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          programsProvider.overrideWith(() => _EmptyProgramsNotifier()),
          nextProgramNameProvider.overrideWith((ref) async => 'Program 2'),
        ],
        child: const MaterialApp(home: NewProgramScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final tips = find.byKey(const Key('new_program_tips'));
    expect(tips, findsOneWidget);
    expect(
      find.descendant(of: tips, matching: find.textContaining('Squat Cycle')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tips, matching: find.textContaining('add weeks')),
      findsOneWidget,
    );
  });
}
