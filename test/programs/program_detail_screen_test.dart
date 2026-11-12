import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/programs/models/program.dart';
import 'package:nomorex/features/programs/models/program_day.dart';
import 'package:nomorex/features/programs/models/program_exercise.dart';
import 'package:nomorex/features/programs/models/program_instance.dart';
import 'package:nomorex/features/programs/models/program_week.dart';
import 'package:nomorex/features/programs/providers/program_detail_provider.dart';
import 'package:nomorex/features/programs/providers/program_instances_list_provider.dart';
import 'package:nomorex/features/programs/screens/program_detail_screen.dart';

class _Detail extends ProgramDetailNotifier {
  _Detail(this._program);
  final Program _program;
  @override
  Future<Program> build(String programId) async => _program;
}

class _FailingDetail extends ProgramDetailNotifier {
  int builds = 0;
  @override
  Future<Program> build(String programId) async {
    builds++;
    throw Exception('PostgrestException(message: boom)');
  }
}

class _Runs extends CurrentProgramInstancesNotifier {
  _Runs(this._runs);
  final List<ProgramInstance> _runs;
  @override
  Future<List<ProgramInstance>> build() async => _runs;
}

ProgramExercise _ex(String dayId, int i, String name) => ProgramExercise(
      id: '$dayId-e$i',
      programDayId: dayId,
      exerciseId: 'x-$name',
      exerciseName: name,
      position: i,
    );

/// Two weeks of three days (one rest day each); day positions run 0-5.
Program _program({String? description}) => Program(
      id: 'p1',
      userId: 'u1',
      name: 'Triphasic Block',
      description: description,
      createdAt: DateTime(2026, 11, 12),
      updatedAt: DateTime(2026, 11, 12),
      weeks: [
        for (var w = 0; w < 2; w++)
          ProgramWeek(
            id: 'w$w',
            programId: 'p1',
            weekNumber: w + 1,
            position: w,
            label: w == 0 ? 'Eccentrics' : null,
            days: [
              for (var d = 0; d < 3; d++)
                ProgramDay(
                  id: 'w$w-d$d',
                  programWeekId: 'w$w',
                  dayNumber: d + 1,
                  title: 'W${w + 1} Day ${d + 1}',
                  position: w * 3 + d,
                  isRestDay: d == 2,
                  exercises: d == 2
                      ? const []
                      : [
                          _ex('w$w-d$d', 0, 'Back squat'),
                          _ex('w$w-d$d', 1, 'Clean'),
                          _ex('w$w-d$d', 2, 'Bench press'),
                          _ex('w$w-d$d', 3, 'Row'),
                        ],
                ),
            ],
          ),
      ],
    );

Future<void> _pump(WidgetTester tester, ProgramDetailNotifier detail, {List<ProgramInstance> runs = const []}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      programDetailProvider('p1').overrideWith(() => detail),
      currentProgramInstancesProvider.overrideWith(() => _Runs(runs)),
    ],
    child: const MaterialApp(home: ProgramDetailScreen(programId: 'p1')),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('day rows name their lifts instead of counting them', (tester) async {
    await _pump(tester, _Detail(_program()));
    expect(find.text('Back squat · Clean · Bench press  +1 more'), findsNWidgets(2));
    expect(find.text('Rest day'), findsOneWidget);
  });

  testWidgets('only the first week is open; a collapsed week shows its summary and opens on tap',
      (tester) async {
    await _pump(tester, _Detail(_program()));
    expect(find.text('W1 Day 1'), findsOneWidget);
    expect(find.text('W2 Day 1'), findsNothing);
    expect(find.text('Week 1 · Eccentrics'), findsOneWidget);
    expect(find.text('3 days · 2 workouts'), findsNWidgets(2));

    await tester.ensureVisible(find.byKey(const Key('program_week_toggle_w1')));
    await tester.tap(find.byKey(const Key('program_week_toggle_w1')));
    await tester.pumpAndSettle();
    expect(find.text('W2 Day 1'), findsOneWidget);
  });

  testWidgets('a running program opens on the week holding today', (tester) async {
    final today = DateTime.now();
    // Started four days ago: today is position 4, in week 2.
    final run = ProgramInstance(
      id: 'run-1',
      programId: 'p1',
      userId: 'u1',
      startedAt: DateTime(today.year, today.month, today.day).subtract(const Duration(days: 4)),
      status: 'active',
    );
    await _pump(tester, _Detail(_program()), runs: [run]);
    expect(find.text('W2 Day 1'), findsOneWidget);
    expect(find.text('W1 Day 1'), findsNothing);
    expect(find.textContaining('In progress', findRichText: true), findsOneWidget);
  });

  testWidgets('a long description is clamped with Show more', (tester) async {
    await _pump(tester, _Detail(_program(description: 'Long block description. ' * 40)));
    expect(find.text('Show more'), findsOneWidget);
    await tester.tap(find.text('Show more'));
    await tester.pumpAndSettle();
    expect(find.text('Show less'), findsOneWidget);
  });

  testWidgets('a short description has no toggle', (tester) async {
    await _pump(tester, _Detail(_program(description: 'Six weeks.')));
    expect(find.byKey(const Key('program_description_toggle')), findsNothing);
  });

  testWidgets('a load failure explains itself without the raw error and retries', (tester) async {
    final failing = _FailingDetail();
    await _pump(tester, failing);
    expect(find.text("Couldn't load this program"), findsOneWidget);
    expect(find.textContaining('Postgrest'), findsNothing);
    final before = failing.builds;
    await tester.tap(find.byKey(const Key('program_detail_retry')));
    await tester.pumpAndSettle();
    expect(failing.builds, greaterThan(before));
  });
}
