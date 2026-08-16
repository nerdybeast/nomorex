import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/core/utils/owner_name.dart';
import 'package:nomorex/features/community/providers/community_program_detail_provider.dart';
import 'package:nomorex/features/community/screens/community_program_detail_screen.dart';
import 'package:nomorex/features/programs/models/program.dart';
import 'package:nomorex/features/programs/models/program_day.dart';
import 'package:nomorex/features/programs/models/program_exercise.dart';
import 'package:nomorex/features/programs/models/program_week.dart';

class _StubCommunityProgramDetailNotifier extends CommunityProgramDetailNotifier {
  _StubCommunityProgramDetailNotifier(this._program);
  final Program _program;
  @override
  Future<Program> build(String programId) async => _program;
}

Program _program({String? owner}) => Program(
      id: 'p1',
      userId: 'other-user',
      name: 'Squat Block',
      description: 'Four weeks of squatting.',
      createdAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 1),
      isPublic: true,
      ownerDisplayName: owner,
      weeks: [
        ProgramWeek(
          id: 'wk1',
          programId: 'p1',
          weekNumber: 1,
          position: 0,
          label: 'Accumulation',
          days: [
            const ProgramDay(
              id: 'd1',
              programWeekId: 'wk1',
              dayNumber: 1,
              title: 'Day 1',
              position: 0,
              exercises: [
                ProgramExercise(
                  id: 'pe1',
                  programDayId: 'd1',
                  exerciseId: 'e1',
                  exerciseName: 'Back Squat',
                  position: 0,
                ),
              ],
            ),
            const ProgramDay(
              id: 'd2',
              programWeekId: 'wk1',
              dayNumber: 2,
              title: 'Day 2',
              position: 1,
              isRestDay: true,
            ),
          ],
        ),
      ],
    );

Future<void> _pump(WidgetTester tester, Program program) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        communityProgramDetailProvider('p1')
            .overrideWith(() => _StubCommunityProgramDetailNotifier(program)),
      ],
      child: const MaterialApp(home: CommunityProgramDetailScreen(programId: 'p1')),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the program, its owner, and its weeks', (tester) async {
    await _pump(tester, _program(owner: 'BeastModeB'));

    expect(find.text('Squat Block'), findsOneWidget);
    expect(find.textContaining('by BeastModeB'), findsOneWidget);
    expect(find.textContaining('1 week'), findsOneWidget);
    expect(find.text('Four weeks of squatting.'), findsOneWidget);
    expect(find.text('Week 1 — Accumulation'), findsOneWidget);
    expect(find.text('Day 1'), findsOneWidget);
    expect(find.text('Day 2'), findsOneWidget);
  });

  testWidgets('falls back to the anonymous label when the owner has no name',
      (tester) async {
    await _pump(tester, _program());

    expect(find.textContaining('by $kAnonymousOwnerName'), findsOneWidget);
  });

  testWidgets('is read-only: no edit action and no Start Program button', (tester) async {
    await _pump(tester, _program(owner: 'BeastModeB'));

    expect(find.text('Read only'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.text('Start Program'), findsNothing);
  });

  testWidgets('a rest day is summarized and not tappable', (tester) async {
    await _pump(tester, _program(owner: 'BeastModeB'));

    expect(find.text('Rest day'), findsOneWidget);
    // Only the day that has exercises offers a chevron into it.
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });
}
