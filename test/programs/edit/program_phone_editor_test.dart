import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nomorex/features/exercises/models/exercise.dart';
import 'package:nomorex/features/exercises/providers/exercises_provider.dart';
import 'package:nomorex/features/profile/providers/profile_provider.dart';
import 'package:nomorex/features/programs/models/program.dart';
import 'package:nomorex/features/programs/models/program_day.dart';
import 'package:nomorex/features/programs/models/program_exercise.dart';
import 'package:nomorex/features/programs/models/program_set.dart';
import 'package:nomorex/features/programs/models/program_week.dart';
import 'package:nomorex/features/programs/providers/program_detail_provider.dart';
import 'package:nomorex/features/programs/screens/edit/program_day_edit_screen.dart';
import 'package:nomorex/features/programs/screens/edit/program_edit_entry.dart';
import 'package:nomorex/features/programs/screens/edit/program_edit_overview_screen.dart';
import 'package:nomorex/features/programs/screens/edit/program_week_edit_screen.dart';
import 'package:nomorex/features/programs/screens/program_edit_screen.dart';
import 'package:nomorex/features/workouts/providers/one_rep_max_provider.dart';
import 'package:nomorex/shared/models/one_rep_max.dart';

/// Records what the screens ask for and applies deletes, so a screen can
/// react to its own week or day going away.
class _Notifier extends ProgramDetailNotifier {
  _Notifier(this.calls);

  final List<String> calls;
  final _removedDays = <String>{};

  @override
  Future<Program> build(String programId) async => _program(removedDays: _removedDays);

  @override
  Future<String> duplicateWeek(String weekId) async {
    calls.add('duplicateWeek $weekId');
    return 'new-week';
  }

  @override
  Future<List<String>> copyDay(String dayId, List<String> weekIds) async {
    calls.add('copyDay $dayId ${weekIds.join(',')}');
    return [for (final _ in weekIds) 'new-day'];
  }

  @override
  Future<String> duplicateDay(String dayId) async {
    calls.add('duplicateDay $dayId');
    return 'new-day';
  }

  @override
  Future<void> removeDay(String dayId) async {
    calls.add('removeDay $dayId');
    _removedDays.add(dayId);
    ref.invalidateSelf();
    await future;
  }

  @override
  Future<void> updateExerciseNotes(String programExerciseId, String? notes) async {
    calls.add('notes $programExerciseId $notes');
  }

  @override
  Future<void> reorderExercises({required String dayId, required List<String> orderedExerciseIds}) async {
    calls.add('reorder $dayId ${orderedExerciseIds.join(',')}');
  }
}

class _Exercises extends ExercisesNotifier {
  @override
  Future<List<Exercise>> build() async => const [];
}

ProgramSet _set(String id, String pe, int pos, {int reps = 3, double? kg, double? pct}) => ProgramSet(
      id: id,
      programExerciseId: pe,
      position: pos,
      weightMode: pct != null ? 'percentage' : 'absolute',
      targetReps: reps,
      absoluteWeightKg: kg,
      percentage: pct,
    );

ProgramExercise _ex(String id, String day, int pos, String name, List<ProgramSet> sets, {String? notes}) =>
    ProgramExercise(id: id, programDayId: day, exerciseId: 'x$id', exerciseName: name, position: pos, notes: notes, sets: sets);

/// Week 1 "Meso 1/4": Day 1 (Muscle Snatch 4 × 3 · 20 kg, Snatch 10 × 1 ·
/// 80%), Day 2 (Front Squat). Week 2: Day 3 (Clean).
Program _program({Set<String> removedDays = const {}}) {
  List<ProgramDay> keep(List<ProgramDay> days) => [for (final d in days) if (!removedDays.contains(d.id)) d];
  return Program(
    id: 'p1',
    userId: 'u1',
    name: 'ZT Strong Like Bull',
    createdAt: DateTime(2026, 11, 1),
    updatedAt: DateTime(2026, 11, 1),
    weeks: [
      ProgramWeek(
        id: 'w1',
        programId: 'p1',
        weekNumber: 1,
        label: 'Meso 1/4',
        position: 0,
        days: keep([
          ProgramDay(id: 'd1', programWeekId: 'w1', dayNumber: 1, title: 'Day 1', position: 0, exercises: [
            _ex('pe1', 'd1', 0, 'Muscle Snatch', [for (var i = 0; i < 4; i++) _set('a$i', 'pe1', i, kg: 20)],
                notes: 'In bottom + press'),
            _ex('pe2', 'd1', 1, 'Snatch', [for (var i = 0; i < 10; i++) _set('b$i', 'pe2', i, reps: 1, pct: 80)]),
          ]),
          ProgramDay(id: 'd2', programWeekId: 'w1', dayNumber: 2, title: 'Day 2', position: 1, exercises: [
            _ex('pe3', 'd2', 0, 'Front Squat', [_set('c0', 'pe3', 0, kg: 80)]),
          ]),
        ]),
      ),
      ProgramWeek(
        id: 'w2',
        programId: 'p1',
        weekNumber: 2,
        position: 1,
        days: keep([
          ProgramDay(id: 'd3', programWeekId: 'w2', dayNumber: 1, title: 'Day 3', position: 2, exercises: [
            _ex('pe4', 'd3', 0, 'Clean', [_set('e0', 'pe4', 0, reps: 1, pct: 85)]),
          ]),
        ]),
      ),
    ],
  );
}

Future<GoRouter> _pump(WidgetTester tester, List<String> calls, {String initial = '/programs/p1/edit', bool phone = true}) async {
  if (phone) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('programs list'))),
      GoRoute(path: '/programs/:id/edit', builder: (_, s) => ProgramEditEntry(programId: s.pathParameters['id']!)),
      GoRoute(
        path: '/programs/:id/edit/weeks/:weekId',
        builder: (_, s) => ProgramWeekEditScreen(programId: s.pathParameters['id']!, weekId: s.pathParameters['weekId']!),
      ),
      GoRoute(
        path: '/programs/:id/edit/days/:dayId',
        builder: (_, s) => ProgramDayEditScreen(programId: s.pathParameters['id']!, dayId: s.pathParameters['dayId']!),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        programDetailProvider('p1').overrideWith(() => _Notifier(calls)),
        exercisesProvider.overrideWith(_Exercises.new),
        oneRepMaxProvider.overrideWith((ref) async => const <String, OneRepMax>{}),
        oneRepMaxByNameProvider.overrideWith((ref) async => const <String, OneRepMax>{}),
        unitPreferenceProvider.overrideWithValue('kg'),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  router.push(initial);
  await tester.pumpAndSettle();
  return router;
}

Future<void> _tapBack(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('on a phone the editor opens on the week overview', (tester) async {
    await _pump(tester, []);

    expect(find.byType(ProgramEditOverviewScreen), findsOneWidget);
    expect(find.text('Week 1 · Meso 1/4'), findsOneWidget);
    expect(find.text('2 days · 3 exercises'), findsOneWidget);
    expect(find.text('Muscle Snatch · Snatch'), findsOneWidget);
    expect(find.text('ZT Strong Like Bull'), findsOneWidget); // the details row
  });

  testWidgets('wider than a phone it keeps the one-page editor', (tester) async {
    await _pump(tester, [], phone: false);

    expect(find.byType(ProgramEditScreen), findsOneWidget);
    expect(find.byType(ProgramEditOverviewScreen), findsNothing);
  });

  testWidgets('a week lists its days with every exercise on one line', (tester) async {
    await _pump(tester, []);
    await tester.tap(find.byKey(const ValueKey('edit_week_card_w1')));
    await tester.pumpAndSettle();

    expect(find.byType(ProgramWeekEditScreen), findsOneWidget);
    expect(find.text('6 exercises · 24 sets'), findsNothing); // only the fixture's days
    expect(find.text('2 exercises · 14 sets'), findsOneWidget);
    expect(find.text('4 × 3 · 20 kg'), findsOneWidget);
    expect(find.text('10 × 1 · 80%'), findsOneWidget);
  });

  testWidgets('the week bar switches weeks in place, and back goes up to the program', (tester) async {
    await _pump(tester, []);
    await tester.tap(find.byKey(const ValueKey('edit_week_card_w1')));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Week 2'));
    await tester.pumpAndSettle();
    expect(find.text('Day 3'), findsOneWidget);
    expect(find.text('Day 1'), findsNothing);

    await _tapBack(tester);
    expect(find.byType(ProgramEditOverviewScreen), findsOneWidget);
  });

  testWidgets('a day lists its exercises, and the day tabs switch days', (tester) async {
    await _pump(tester, [], initial: '/programs/p1/edit/days/d1');

    expect(find.text('Muscle Snatch'), findsOneWidget);
    expect(find.text('4 × 3'), findsOneWidget);
    expect(find.text('20 kg'), findsOneWidget);
    expect(find.text('In bottom + press'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(RegExp('^Day 2,')));
    await tester.pumpAndSettle();
    expect(find.text('Front Squat'), findsOneWidget);
    expect(find.text('Muscle Snatch'), findsNothing);
  });

  testWidgets('tapping an exercise edits it in a sheet that saves its notes', (tester) async {
    final calls = <String>[];
    await _pump(tester, calls, initial: '/programs/p1/edit/days/d1');

    await tester.tap(find.byKey(const ValueKey('edit_exercise_row_pe2')));
    await tester.pumpAndSettle();
    expect(find.text('Day 1 · exercise 2'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Notes (e.g. build to a heavy triple)'), 'Wave singles');
    await tester.tap(find.byKey(const Key('edit_exercise_done')));
    await tester.pumpAndSettle();

    expect(calls, contains('notes pe2 Wave singles'));
    expect(find.text('Day 1 · exercise 2'), findsNothing);
  });

  testWidgets('dragging an exercise reorders the day', (tester) async {
    final calls = <String>[];
    await _pump(tester, calls, initial: '/programs/p1/edit/days/d1');

    final drag = await tester.startGesture(tester.getCenter(find.byIcon(Icons.drag_indicator).first));
    await tester.pump(kPressTimeout);
    for (var i = 0; i < 10; i++) {
      await drag.moveBy(const Offset(0, 20));
      await tester.pump();
    }
    await drag.up();
    await tester.pumpAndSettle();

    expect(calls, contains('reorder d1 pe2,pe1'));
  });

  testWidgets('Duplicate week from a week card', (tester) async {
    final calls = <String>[];
    await _pump(tester, calls);

    await tester.tap(find.byKey(const ValueKey('edit_week_more_w1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicate week'));
    await tester.pumpAndSettle();

    expect(calls, ['duplicateWeek w1']);
    expect(find.text('Week 2 added as a copy of Week 1'), findsOneWidget);
  });

  testWidgets('Copy to other weeks copies the day to the weeks picked', (tester) async {
    final calls = <String>[];
    await _pump(tester, calls, initial: '/programs/p1/edit/weeks/w1');

    await tester.tap(find.byKey(const ValueKey('edit_day_more_d1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy to other weeks…'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('copy_to_w2')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('copy_day_confirm')));
    await tester.pumpAndSettle();

    expect(calls, ['copyDay d1 w2']);
    expect(find.text('Day 1 copied to Week 2'), findsOneWidget);
  });

  testWidgets('deleting the day you are on goes back to its week', (tester) async {
    final calls = <String>[];
    await _pump(tester, calls, initial: '/programs/p1/edit/weeks/w1');
    await tester.tap(find.byKey(const ValueKey('edit_day_card_d2')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('edit_day_more')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete day'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete')); // the confirm dialog
    await tester.pumpAndSettle();

    expect(calls, ['removeDay d2']);
    expect(find.byType(ProgramWeekEditScreen), findsOneWidget);
    expect(find.byType(ProgramDayEditScreen), findsNothing);
  });

  testWidgets('a link to a week that no longer exists says so', (tester) async {
    await _pump(tester, [], initial: '/programs/p1/edit/weeks/gone');

    expect(find.text('This week no longer exists.'), findsOneWidget);
    await tester.tap(find.text('Back to the program'));
    await tester.pumpAndSettle();
    expect(find.byType(ProgramWeekEditScreen), findsNothing);
  });
}
