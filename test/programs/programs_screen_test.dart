import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/programs/models/program.dart';
import 'package:nomorex/features/programs/models/program_instance.dart';
import 'package:nomorex/features/programs/providers/program_instances_list_provider.dart';
import 'package:nomorex/features/programs/providers/programs_provider.dart';
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

Program _program(String id, String name, {String? description}) => Program(
      id: id,
      userId: 'u1',
      name: name,
      description: description,
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
    );

void main() {
  testWidgets('a description longer than 200 characters is truncated with an ellipsis', (
    tester,
  ) async {
    final longDescription = 'A' * 250;
    final programs = [_program('p1', 'Long Program', description: longDescription)];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          programsProvider.overrideWith(() => _StubProgramsNotifier(programs)),
          currentProgramInstancesProvider.overrideWith(() => _EmptyProgramInstancesNotifier()),
        ],
        child: const MaterialApp(home: ProgramsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final expectedPreview = '${'A' * 200}...';
    expect(find.text(expectedPreview), findsOneWidget);
    expect(find.text(longDescription), findsNothing);
  });

  testWidgets('a program with no description shows an italicized, faded placeholder', (
    tester,
  ) async {
    final programs = [_program('p1', 'Bare Program')];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          programsProvider.overrideWith(() => _StubProgramsNotifier(programs)),
          currentProgramInstancesProvider.overrideWith(() => _EmptyProgramInstancesNotifier()),
        ],
        child: const MaterialApp(home: ProgramsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final placeholder = tester.widget<Text>(find.text('No Description.'));
    expect(placeholder.style?.fontStyle, FontStyle.italic);

    final context = tester.element(find.text('No Description.'));
    final colorScheme = Theme.of(context).colorScheme;
    expect(placeholder.style?.color, colorScheme.onSurfaceVariant);
  });

  testWidgets('search filters programs by name and by description', (tester) async {
    final programs = [
      _program('p1', 'Powerlifting Block', description: 'Squat, bench, deadlift focus.'),
      _program('p2', 'Hypertrophy Plan', description: 'High volume accessory work.'),
      _program('p3', 'Deload Week', description: null),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          programsProvider.overrideWith(() => _StubProgramsNotifier(programs)),
          currentProgramInstancesProvider.overrideWith(() => _EmptyProgramInstancesNotifier()),
        ],
        child: const MaterialApp(home: ProgramsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Powerlifting Block'), findsOneWidget);
    expect(find.text('Hypertrophy Plan'), findsOneWidget);
    expect(find.text('Deload Week'), findsOneWidget);

    // Matches on name.
    await tester.enterText(find.byType(TextField), 'Hypertrophy');
    await tester.pumpAndSettle();
    expect(find.text('Hypertrophy Plan'), findsOneWidget);
    expect(find.text('Powerlifting Block'), findsNothing);
    expect(find.text('Deload Week'), findsNothing);

    // Matches on description even when the query isn't in the name.
    await tester.enterText(find.byType(TextField), 'deadlift');
    await tester.pumpAndSettle();
    expect(find.text('Powerlifting Block'), findsOneWidget);
    expect(find.text('Hypertrophy Plan'), findsNothing);
    expect(find.text('Deload Week'), findsNothing);

    // No matches shows the search-specific empty state.
    await tester.enterText(find.byType(TextField), 'nonexistent');
    await tester.pumpAndSettle();
    expect(find.text('No programs match your search.'), findsOneWidget);
  });
}
