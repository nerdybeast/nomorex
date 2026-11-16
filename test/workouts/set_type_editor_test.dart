import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/exercises/models/exercise.dart';
import 'package:nomorex/features/exercises/providers/exercises_provider.dart';
import 'package:nomorex/features/workouts/providers/one_rep_max_provider.dart';
import 'package:nomorex/features/workouts/utils/parsed_set.dart';
import 'package:nomorex/features/workouts/widgets/set_editor.dart';
import 'package:nomorex/shared/models/editable_set_row.dart';
import 'package:nomorex/shared/models/one_rep_max.dart';
import 'package:nomorex/shared/models/set_type.dart';

class _StubExercisesNotifier extends ExercisesNotifier {
  @override
  Future<List<Exercise>> build() async => const [];
}

/// A phone-sized editor: the sheets open as bottom sheets, as on a phone.
Future<void> _pump(
  WidgetTester tester,
  SetEditor editor, {
  Size size = const Size(390, 844),
  Map<String, OneRepMax> oneRepMaxes = const {},
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      exercisesProvider.overrideWith(() => _StubExercisesNotifier()),
      oneRepMaxProvider.overrideWith((ref) async => oneRepMaxes),
      oneRepMaxByNameProvider.overrideWith((ref) async => const {}),
    ],
    child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: editor))),
  ));
  await tester.pumpAndSettle();
}

SetEditor _editor({
  List<EditableSetRow> sets = const [],
  void Function(List<ParsedSet>)? onPct,
  void Function(AbsoluteSetBatch)? onAbs,
  void Function(List<String> ids, int count, Map<String, Object?> prescription)? onReplace,
}) =>
    SetEditor(
      sets: sets,
      unit: 'kg',
      currentExerciseId: 'e1',
      currentExerciseName: 'Back Squat',
      onAddPercentageSets: (x) async => (onPct ?? (_) {})(x),
      onAddAbsoluteSets: (x) async => (onAbs ?? (_) {})(x),
      onReplaceGroup: (ids, count, rx) async => onReplace?.call(ids, count, rx),
      onReorderSets: (_) async {},
    );

const _warmupRow = EditableSetRow(
  id: 's1',
  weightMode: 'absolute',
  targetReps: 5,
  absoluteWeightKg: 40,
  setType: SetType.warmup,
);
const _workingRow = EditableSetRow(id: 's2', weightMode: 'absolute', targetReps: 3, absoluteWeightKg: 100);

void main() {
  testWidgets('a batch is working sets unless another type is chosen', (tester) async {
    AbsoluteSetBatch? batch;
    await _pump(tester, _editor(onAbs: (b) => batch = b));

    await tester.tap(find.text('Add sets (weight)'));
    await tester.pumpAndSettle();
    final segments = tester.widget<SegmentedButton<SetType>>(find.byKey(const Key('set_editor_set_type')));
    expect(segments.selected, {SetType.working});

    await tester.tap(find.byKey(const Key('set_editor_add')));
    await tester.pumpAndSettle();
    expect(batch!.setType, SetType.working);
  });

  testWidgets('choosing Warm-up in the weight sheet adds warm-up sets, and the preview says so', (tester) async {
    AbsoluteSetBatch? batch;
    await _pump(tester, _editor(onAbs: (b) => batch = b));

    await tester.tap(find.text('Add sets (weight)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('set_editor_set_type_warmup')));
    await tester.pumpAndSettle();

    final preview = tester.widget<RichText>(
      find.descendant(of: find.byKey(const Key('set_editor_preview')), matching: find.byType(RichText)).first,
    );
    expect(preview.text.toPlainText(), startsWith('Warm-up · 1 × 1'));

    await tester.tap(find.byKey(const Key('set_editor_add')));
    await tester.pumpAndSettle();
    expect(batch!.setType, SetType.warmup);
  });

  testWidgets('choosing Cool-down in the %1RM sheet marks every set of the batch', (tester) async {
    List<ParsedSet>? added;
    await _pump(tester, _editor(onPct: (p) => added = p));

    await tester.tap(find.text('Add sets (%)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('set_editor_set_type_cooldown')));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Increase Sets'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('set_editor_add')));
    await tester.tap(find.byKey(const Key('set_editor_add')));
    await tester.pumpAndSettle();

    expect(added!.map((s) => s.setType), [SetType.cooldown, SetType.cooldown]);
  });

  testWidgets('each run of one type gets a header; rows carry no type label', (tester) async {
    await _pump(tester, _editor(sets: const [_warmupRow, _workingRow]));

    expect(find.text('WARM-UP'), findsOneWidget);
    expect(find.text('WORKING'), findsOneWidget);
    expect(find.text('1 × 5'), findsOneWidget);
    expect(find.text('1 × 3'), findsOneWidget);
  });

  testWidgets('only working sets: no headers at all', (tester) async {
    await _pump(tester, _editor(sets: const [_workingRow]));
    expect(find.text('WORKING'), findsNothing);
  });

  testWidgets('a group is retyped from its menu, rewriting it with the same prescription', (tester) async {
    final calls = <(List<String>, int, Map<String, Object?>)>[];
    await _pump(tester, _editor(sets: const [_warmupRow, _workingRow], onReplace: (i, c, r) => calls.add((i, c, r))));

    await tester.tap(find.byKey(const ValueKey('set_group_more_s2')));
    await tester.pumpAndSettle();
    expect(find.text('Mark as working set'), findsNothing, reason: 'it already is');
    await tester.tap(find.text('Mark as cool-down set'));
    await tester.pumpAndSettle();

    final (ids, count, rx) = calls.single;
    expect(ids, ['s2']);
    expect(count, 1);
    expect(rx['set_type'], 'cooldown');
    expect(rx['target_reps'], 3);
    expect(rx['absolute_weight_kg'], 100.0);
  });

  testWidgets('tapping a group reopens the sheet filled in, type included, and saves the group', (tester) async {
    final calls = <(List<String>, int, Map<String, Object?>)>[];
    await _pump(tester, _editor(sets: const [_warmupRow], onReplace: (i, c, r) => calls.add((i, c, r))));

    await tester.tap(find.byKey(const ValueKey('set_group_s1')));
    await tester.pumpAndSettle();
    final segments = tester.widget<SegmentedButton<SetType>>(find.byKey(const Key('set_editor_set_type')));
    expect(segments.selected, {SetType.warmup});
    expect(find.text('Save 1 set'), findsOneWidget);
    await tester.tap(find.text('Save 1 set'));
    await tester.pumpAndSettle();

    final (ids, count, rx) = calls.single;
    expect(ids, ['s1']);
    expect(count, 1);
    expect(rx['set_type'], 'warmup');
    expect(rx['absolute_weight_kg'], 40.0);
  });

  testWidgets('a failed save shows a snackbar instead of failing silently', (tester) async {
    await _pump(
      tester,
      SetEditor(
        sets: const [_workingRow],
        unit: 'kg',
        currentExerciseId: 'e1',
        currentExerciseName: 'Back Squat',
        onAddPercentageSets: (_) async {},
        onAddAbsoluteSets: (_) async {},
        onReplaceGroup: (_, _, _) async => throw Exception('offline'),
        onReorderSets: (_) async {},
      ),
    );
    await tester.tap(find.byKey(const ValueKey('set_group_more_s2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove set'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't save the sets. Try again."), findsOneWidget);
  });

  testWidgets('controls are named for the group they act on', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _editor(sets: const [_warmupRow]));

    expect(find.byTooltip('Options for 1 warm-up set of 5 reps'), findsOneWidget);
    final row = tester.getSemantics(find.byKey(const ValueKey('set_group_s1')));
    expect(row.label, startsWith('1 warm-up set of 5 reps, 40 kg'));
    expect(row.flagsCollection.isButton, isTrue);
    handle.dispose();
  });

  group('row layout', () {
    const pctRow = EditableSetRow(
      id: 'p1',
      weightMode: 'percentage',
      targetReps: 3,
      percentage: 60,
      setType: SetType.warmup,
    );

    testWidgets('on a phone the prescription keeps its line and the load drops below it', (tester) async {
      // A card inside a phone's padding: the width the edit screen gives it.
      await _pump(
        tester,
        _editor(sets: const [pctRow]),
        size: const Size(330, 700),
        oneRepMaxes: const {'e1': OneRepMax.measured(100)},
      );

      final prescription = find.text('60% of 1RM');
      final load = find.byKey(const ValueKey('set_editor_resolved_p1'));
      // Room to read, not a column of single characters (it was ~30px wide).
      // Widget tests draw text in a wide placeholder font, so this checks the
      // width the row gives it rather than the number of lines.
      expect(tester.getSize(prescription).width, greaterThan(100));
      expect(tester.getTopLeft(load).dy, greaterThan(tester.getBottomLeft(prescription).dy - 1));
    });

    testWidgets('on a wide screen the load ends the same line', (tester) async {
      await _pump(
        tester,
        _editor(sets: const [pctRow]),
        size: const Size(900, 700),
        oneRepMaxes: const {'e1': OneRepMax.measured(100)},
      );

      final prescription = tester.getCenter(find.text('60% of 1RM'));
      final load = tester.getCenter(find.byKey(const ValueKey('set_editor_resolved_p1')));
      expect((load.dy - prescription.dy).abs(), lessThan(4));
      expect(load.dx, greaterThan(prescription.dx));
    });
  });

  group('the editor keeps runs in type order and work safe', () {
    /// Every editor callback, in the order they're made.
    List<String> calls = [];
    Map<String, Object?>? lastRx;
    SetEditor recording(List<EditableSetRow> sets, {bool failReplace = false}) => SetEditor(
          sets: sets,
          unit: 'kg',
          currentExerciseId: 'e1',
          currentExerciseName: 'Back Squat',
          onAddPercentageSets: (p) async => calls.add('addPct:${p.length}:${p.first.setType.dbValue}'),
          onAddAbsoluteSets: (b) async => calls.add('addAbs:${b.sets}:${b.setType.dbValue}:${b.weightKg}'),
          onReplaceGroup: (ids, count, rx) async {
            if (failReplace) throw Exception('offline');
            lastRx = rx;
            calls.add('replace:${ids.join(',')}:$count');
          },
          onReorderSets: (ids) async => calls.add('reorder:${ids.join(',')}'),
        );

    setUp(() {
      calls = [];
      lastRx = null;
    });

    const working = EditableSetRow(id: 'w1', weightMode: 'absolute', targetReps: 3, absoluteWeightKg: 100);
    const trailing = EditableSetRow(id: 't1', weightMode: 'absolute', targetReps: 5, absoluteWeightKg: 60);

    testWidgets('marking a trailing group as warm-up moves it above the working sets, then retypes it',
        (tester) async {
      await _pump(tester, recording(const [working, trailing]));

      await tester.tap(find.byKey(const ValueKey('set_group_more_t1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark as warm-up set'));
      await tester.pumpAndSettle();

      expect(calls, ['reorder:t1,w1', 'replace:t1:1']);
      expect(lastRx!['set_type'], 'warmup');
    });

    testWidgets('a group already in place is retyped without a move', (tester) async {
      await _pump(tester, recording(const [working, trailing]));

      await tester.tap(find.byKey(const ValueKey('set_group_more_t1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark as cool-down set'));
      await tester.pumpAndSettle();

      expect(calls, ['replace:t1:1']);
    });

    testWidgets('a failed save keeps the sheet open with the error and what was entered', (tester) async {
      await _pump(tester, recording(const [working], failReplace: true));

      await tester.tap(find.byKey(const ValueKey('set_group_w1')));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Increase Reps'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save 1 set'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('set_editor_error')), findsOneWidget);
      expect(find.text('Save 1 set'), findsOneWidget, reason: 'the sheet is still open');
      expect(find.text('Edit sets · Back Squat'), findsOneWidget);
    });

    testWidgets('"Edit the last set only" has no Sets stepper, so it edits exactly one set', (tester) async {
      await _pump(tester, recording(const [
        working,
        EditableSetRow(id: 'w2', weightMode: 'absolute', targetReps: 3, absoluteWeightKg: 100),
      ]));

      await tester.tap(find.byKey(const ValueKey('set_group_more_w1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit the last set only'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Increase Sets'), findsNothing);
      await tester.tap(find.text('Save 1 set'));
      await tester.pumpAndSettle();
      expect(calls, ['replace:w2:1']);
    });

    testWidgets('removing offers Undo, which adds the same sets back', (tester) async {
      await _pump(tester, recording(const [working]));

      await tester.tap(find.byKey(const ValueKey('set_group_more_w1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove set'));
      await tester.pumpAndSettle();
      expect(calls, ['replace:w1:0']);
      expect(find.text('Removed 1 × 3'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(calls[1], 'addAbs:1:working:100.0');
    });

    testWidgets('a percentage group with no 1RM says so and links to the PR', (tester) async {
      await _pump(tester, recording(const [
        EditableSetRow(id: 'p1', weightMode: 'percentage', targetReps: 5, percentage: 70),
      ]));

      expect(find.byKey(const ValueKey('set_editor_no_1rm_p1')), findsOneWidget);
      expect(find.textContaining('No 1RM yet'), findsOneWidget);
      expect(find.text('set PR'), findsOneWidget);
    });
  });
}
