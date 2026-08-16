import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/profile/providers/profile_provider.dart';
import 'package:nomorex/features/programs/models/program.dart';
import 'package:nomorex/features/programs/models/program_day.dart';
import 'package:nomorex/features/programs/models/program_exercise.dart';
import 'package:nomorex/features/programs/models/program_set.dart';
import 'package:nomorex/features/programs/models/program_week.dart';
import 'package:nomorex/features/programs/providers/program_detail_provider.dart';
import 'package:nomorex/features/programs/screens/program_day_detail_screen.dart';
import 'package:nomorex/features/workouts/providers/one_rep_max_provider.dart';

class _StubProgramDetailNotifier extends ProgramDetailNotifier {
  _StubProgramDetailNotifier(this._program);
  final Program _program;
  @override
  Future<Program> build(String programId) async => _program;
}

/// A program whose Day 1 programs Back Squat at 80% of 1RM. The exercise id is
/// the *owner's* — a viewer browsing this as a public program has their own,
/// different id for the same lift.
Program _program() => Program(
      id: 'p1',
      userId: 'other-user',
      name: 'Squat Block',
      createdAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 1),
      weeks: [
        ProgramWeek(
          id: 'wk1',
          programId: 'p1',
          weekNumber: 1,
          position: 0,
          days: const [
            ProgramDay(
              id: 'd1',
              programWeekId: 'wk1',
              dayNumber: 1,
              title: 'Day 1',
              position: 0,
              exercises: [
                ProgramExercise(
                  id: 'pe1',
                  programDayId: 'd1',
                  exerciseId: 'owner-e1',
                  exerciseName: 'Back Squat',
                  position: 0,
                  sets: [
                    ProgramSet(
                      id: 'ps1',
                      programExerciseId: 'pe1',
                      position: 0,
                      weightMode: 'percentage',
                      targetReps: 5,
                      percentage: 80,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );

Future<void> _pump(
  WidgetTester tester, {
  Map<String, double> oneRepMaxes = const {},
  Map<String, double> oneRepMaxesByName = const {},
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        programDetailProvider('p1').overrideWith(() => _StubProgramDetailNotifier(_program())),
        oneRepMaxProvider.overrideWith((ref) async => oneRepMaxes),
        oneRepMaxByNameProvider.overrideWith((ref) async => oneRepMaxesByName),
        unitPreferenceProvider.overrideWithValue('kg'),
      ],
      child: const MaterialApp(
        home: ProgramDayDetailScreen(programId: 'p1', dayId: 'd1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('resolves a percentage set against the viewer 1RM matched by id',
      (tester) async {
    await _pump(tester, oneRepMaxes: {'owner-e1': 100});

    expect(find.textContaining('5 reps · 80% of 1RM'), findsOneWidget);
    expect(find.textContaining('80.0 kg'), findsOneWidget);
  });

  testWidgets(
      'resolves by exercise name when the viewer has their own id for the same lift',
      (tester) async {
    // The viewer's PR hangs off *their* exercise row, so nothing matches by id.
    // Without the name fallback this set would render as unresolvable forever.
    await _pump(tester, oneRepMaxesByName: {'back squat': 100});

    expect(find.textContaining('80.0 kg'), findsOneWidget);
  });

  testWidgets('shows no resolved weight when the viewer has no 1RM at all', (tester) async {
    await _pump(tester);

    expect(find.textContaining('5 reps · 80% of 1RM'), findsOneWidget);
    expect(find.textContaining('kg'), findsNothing);
  });
}
