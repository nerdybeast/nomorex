import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/exercises/models/exercise.dart';
import 'package:nomorex/features/exercises/providers/exercises_provider.dart';
import 'package:nomorex/features/programs/models/program.dart';
import 'package:nomorex/features/programs/models/program_exercise.dart';
import 'package:nomorex/features/programs/models/program_set.dart';
import 'package:nomorex/features/programs/providers/program_detail_provider.dart';
import 'package:nomorex/features/programs/widgets/set_group_editor.dart';
import 'package:nomorex/features/workouts/providers/one_rep_max_provider.dart';
import 'package:nomorex/shared/models/one_rep_max.dart';

class _Notifier extends ProgramDetailNotifier {
  _Notifier(this.calls);

  final List<(List<String>, int, Map<String, Object?>)> calls;

  @override
  Future<Program> build(String programId) async =>
      Program(id: 'p1', userId: 'u1', name: 'P', createdAt: DateTime(2026), updatedAt: DateTime(2026));

  @override
  Future<void> replaceSetGroup(List<String> setIds, int count, Map<String, Object?> prescription) async {
    calls.add((setIds, count, prescription));
  }

  @override
  Future<void> reorderSets(String programExerciseId, List<String> orderedSetIds) async {
    calls.add((orderedSetIds, -1, const {}));
  }
}

class _Exercises extends ExercisesNotifier {
  @override
  Future<List<Exercise>> build() async => const [
        Exercise(id: 'squat', name: 'Back Squat', isPredefined: true),
        Exercise(id: 'clean', name: 'Clean', isPredefined: true),
      ];
}

ProgramSet _abs(String id, int pos, double kg, {int reps = 3}) => ProgramSet(
      id: id, programExerciseId: 'pe1', position: pos, weightMode: 'absolute', targetReps: reps, absoluteWeightKg: kg);

ProgramSet _pct(String id, int pos, double pct, {String? basisId, String? basisName}) => ProgramSet(
      id: id,
      programExerciseId: 'pe1',
      position: pos,
      weightMode: 'percentage',
      targetReps: 1,
      percentage: pct,
      basisExerciseId: basisId,
      basisExerciseName: basisName,
      note: 'fast',
    );

/// Back Squat: three 3 × 50 kg, then two singles at 80% of Clean.
ProgramExercise _exercise() => ProgramExercise(
      id: 'pe1',
      programDayId: 'd1',
      exerciseId: 'squat',
      exerciseName: 'Back Squat',
      position: 0,
      sets: [
        _abs('a0', 0, 50),
        _abs('a1', 1, 50),
        _abs('a2', 2, 50),
        _pct('b0', 3, 80, basisId: 'clean', basisName: 'Clean'),
        _pct('b1', 4, 80, basisId: 'clean', basisName: 'Clean'),
      ],
    );

Future<List<(List<String>, int, Map<String, Object?>)>> _pump(WidgetTester tester, {String unit = 'kg'}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final calls = <(List<String>, int, Map<String, Object?>)>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        programDetailProvider('p1').overrideWith(() => _Notifier(calls)),
        exercisesProvider.overrideWith(_Exercises.new),
        oneRepMaxProvider.overrideWith((ref) async => const {'clean': OneRepMax.measured(100)}),
        oneRepMaxByNameProvider.overrideWith((ref) async => const <String, OneRepMax>{}),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SetGroupEditor(programId: 'p1', exercise: _exercise(), unit: unit),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return calls;
}

void main() {
  testWidgets('identical consecutive sets show as one row each', (tester) async {
    await _pump(tester);

    expect(find.text('3 × 3'), findsOneWidget);
    expect(find.text('50 kg'), findsOneWidget);
    expect(find.text('2 × 1'), findsOneWidget);
    expect(find.text('80% of Clean'), findsOneWidget);
    expect(find.text('80 kg'), findsOneWidget); // resolved from the Clean 1RM
  });

  testWidgets('editing a group rewrites all of its sets', (tester) async {
    final calls = await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('set_group_a0')));
    await tester.pumpAndSettle();
    expect(find.text('Edit sets · Back Squat'), findsOneWidget);
    expect(find.text('Save 3 sets'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Increase Sets'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save 4 sets'));
    await tester.pumpAndSettle();

    expect(calls, hasLength(1));
    final (ids, count, rx) = calls.single;
    expect(ids, ['a0', 'a1', 'a2']);
    expect(count, 4);
    expect(rx['weight_mode'], 'absolute');
    expect(rx['target_reps'], 3);
    expect(rx['absolute_weight_kg'], 50.0);
  });

  testWidgets('a percentage group keeps its basis lift and note', (tester) async {
    final calls = await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('set_group_b0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save 2 sets'));
    await tester.pumpAndSettle();

    final (ids, count, rx) = calls.single;
    expect(ids, ['b0', 'b1']);
    expect(count, 2);
    expect(rx['weight_mode'], 'percentage');
    expect(rx['percentage'], 80.0);
    expect(rx['basis_exercise_id'], 'clean');
    expect(rx['note'], 'fast');
  });

  testWidgets('"Edit the last set only" rewrites just that set', (tester) async {
    final calls = await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('set_group_more_a0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit the last set only'));
    await tester.pumpAndSettle();
    expect(find.text('Save 1 set'), findsOneWidget);
    await tester.tap(find.text('Save 1 set'));
    await tester.pumpAndSettle();

    final (ids, count, _) = calls.single;
    expect(ids, ['a2']);
    expect(count, 1);
  });

  testWidgets('deleting a group asks first, then removes all of it', (tester) async {
    final calls = await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('set_group_more_a0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete 3 sets'));
    await tester.pumpAndSettle();
    expect(find.text('Delete 3 sets?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    final (ids, count, _) = calls.single;
    expect(ids, ['a0', 'a1', 'a2']);
    expect(count, 0);
  });

  testWidgets('a weight edited in lb is saved back in kg', (tester) async {
    final calls = await _pump(tester, unit: 'lbs');

    expect(find.textContaining('110.2 lbs'), findsOneWidget); // 50 kg, shown in lb
    await tester.tap(find.byKey(const ValueKey('set_group_a0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save 3 sets'));
    await tester.pumpAndSettle();

    final (_, _, rx) = calls.single;
    expect(rx['absolute_weight_kg'] as double, closeTo(50, 0.001));
  });
}
