import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/shared/models/one_rep_max.dart';
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
          notes: 'EMOM 10 min after the main lift',
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
                ProgramSet(
                  id: 'ps2',
                  programExerciseId: 'pe1',
                  position: 1,
                  weightMode: 'percentage',
                  targetReps: 7,
                  targetRepsMax: 9,
                  percentage: 67,
                  percentageMax: 72.5,
                  rpeMin: 6,
                  rpeMax: 7,
                ),
                // Open load (#66): no prescribed weight, the lifter picks it.
                ProgramSet(
                  id: 'ps3',
                  programExerciseId: 'pe1',
                  position: 2,
                  weightMode: 'open',
                  targetReps: 10,
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
  Map<String, OneRepMax> oneRepMaxes = const {},
  Map<String, OneRepMax> oneRepMaxesByName = const {},
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        programDetailProvider(
          'p1',
        ).overrideWith(() => _StubProgramDetailNotifier(_program())),
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
  testWidgets('shows the day notes', (tester) async {
    await _pump(tester);

    expect(find.text('EMOM 10 min after the main lift'), findsOneWidget);
  });

  // The main lift's group rows: "1 × 5 · 80% · 80 kg", "1 × 7–9 · 67–72.5% ·
  // RPE 6–7 · 134–145 kg", "1 × 10 · choose load".
  Finder groupRow(String label) => find.ancestor(of: find.text(label), matching: find.byType(Row)).first;

  testWidgets(
    'resolves a percentage set against the viewer 1RM matched by id',
    (tester) async {
      await _pump(
        tester,
        oneRepMaxes: const {'owner-e1': OneRepMax.measured(100)},
      );

      expect(find.text('1 × 5'), findsOneWidget);
      expect(find.descendant(of: groupRow('1 × 5'), matching: find.text('80%')), findsOneWidget);
      expect(find.descendant(of: groupRow('1 × 5'), matching: find.text('80 kg')), findsOneWidget);
    },
  );

  testWidgets(
    'resolves by exercise name when the viewer has their own id for the same lift',
    (tester) async {
      // The viewer's PR hangs off *their* exercise row, so nothing matches by id.
      // Without the name fallback this set would render as unresolvable forever.
      await _pump(
        tester,
        oneRepMaxesByName: const {'back squat': OneRepMax.measured(100)},
      );

      expect(find.descendant(of: groupRow('1 × 5'), matching: find.text('80 kg')), findsOneWidget);
    },
  );

  testWidgets('shows no resolved weight and offers Set PR when the viewer has no 1RM at all', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.descendant(of: groupRow('1 × 5'), matching: find.text('80%')), findsOneWidget);
    expect(find.textContaining(' kg'), findsNothing);
    expect(find.text('set PR'), findsWidgets);
  });

  testWidgets('a %1RM range shows the range and resolves both ends from the 1RM', (tester) async {
    await _pump(tester, oneRepMaxes: const {'owner-e1': OneRepMax.estimated(200)});

    expect(find.descendant(of: groupRow('1 × 7–9'), matching: find.text('67–72.5% · RPE 6–7')), findsOneWidget);
    expect(find.descendant(of: groupRow('1 × 7–9'), matching: find.text('134–145 kg (est.)')), findsOneWidget);
    // The basis line and the headline both say the load rests on an estimate.
    expect(find.textContaining('200 kg est. 1RM'), findsOneWidget);
    expect(find.textContaining('(est.)', findRichText: true), findsWidgets);
  });

  testWidgets('an open-load set says "choose load" even when the viewer has a 1RM', (tester) async {
    await _pump(tester, oneRepMaxes: const {'owner-e1': OneRepMax.measured(100)});

    expect(find.descendant(of: groupRow('1 × 10'), matching: find.text('choose load')), findsOneWidget);
    expect(find.descendant(of: groupRow('1 × 10'), matching: find.textContaining('kg')), findsNothing);
  });

  testWidgets('the day opens with its shape: lifts, sets and peak intensity', (tester) async {
    await _pump(tester);

    expect(find.text('lift'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // sets
    expect(find.text('80%'), findsWidgets);
    expect(find.text('peak intensity'), findsOneWidget);
    expect(find.byKey(const Key('program_day_main_lift')), findsOneWidget);
  });

  group('Set PR on a lift measured against another lift', () {
    // Day 2: Snatch (no %), then Snatch Pull at % of Clean, and a Front Squat
    // at % of Clean. Neither basis is the main lift's, and the viewer has no
    // Clean 1RM.
    Program basisProgram({bool mainNeedsClean = false}) => Program(
          id: 'p1',
          userId: 'u1',
          name: 'Pull Block',
          createdAt: DateTime(2026, 7, 1),
          updatedAt: DateTime(2026, 7, 1),
          weeks: [
            ProgramWeek(id: 'wk1', programId: 'p1', weekNumber: 1, position: 0, days: [
              ProgramDay(id: 'd1', programWeekId: 'wk1', dayNumber: 1, title: 'Day 1', position: 0, exercises: [
                ProgramExercise(
                  id: 'pe1',
                  programDayId: 'd1',
                  exerciseId: 'snatch',
                  exerciseName: 'Snatch',
                  position: 0,
                  sets: [
                    mainNeedsClean
                        ? const ProgramSet(id: 'm1', programExerciseId: 'pe1', position: 0, weightMode: 'percentage', targetReps: 2, percentage: 60, basisExerciseId: 'clean', basisExerciseName: 'Clean')
                        : const ProgramSet(id: 'm1', programExerciseId: 'pe1', position: 0, weightMode: 'absolute', targetReps: 2, absoluteWeightKg: 50),
                  ],
                ),
                const ProgramExercise(
                  id: 'pe2',
                  programDayId: 'd1',
                  exerciseId: 'pull',
                  exerciseName: 'Clean Pull',
                  position: 1,
                  sets: [
                    ProgramSet(id: 'p1s', programExerciseId: 'pe2', position: 0, weightMode: 'percentage', targetReps: 3, percentage: 90, basisExerciseId: 'clean', basisExerciseName: 'Clean'),
                  ],
                ),
              ]),
            ]),
          ],
        );

    Future<void> pumpWith(WidgetTester tester, Program program) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            programDetailProvider('p1').overrideWith(() => _StubProgramDetailNotifier(program)),
            oneRepMaxProvider.overrideWith((ref) async => const <String, OneRepMax>{}),
            oneRepMaxByNameProvider.overrideWith((ref) async => const <String, OneRepMax>{}),
            unitPreferenceProvider.overrideWithValue('kg'),
          ],
          child: const MaterialApp(home: ProgramDayDetailScreen(programId: 'p1', dayId: 'd1')),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('names the basis lift so it is clear whose PR it records', (tester) async {
      await pumpWith(tester, basisProgram());
      expect(find.text('set Clean PR'), findsOneWidget);
    });

    testWidgets('a basis the main lift already links says why the load is missing instead', (tester) async {
      await pumpWith(tester, basisProgram(mainNeedsClean: true));
      expect(find.text('set Clean PR'), findsOneWidget); // the hero's, once
      expect(find.text('needs Clean PR'), findsOneWidget);
    });
  });
}
