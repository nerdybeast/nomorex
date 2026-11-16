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
  void Function(String, SetType)? onChangeSetType,
}) =>
    SetEditor(
      sets: sets,
      unit: 'kg',
      currentExerciseId: 'e1',
      currentExerciseName: 'Back Squat',
      onAddPercentageSets: onPct ?? (_) {},
      onAddAbsoluteSets: onAbs ?? (_) {},
      onDeleteSet: (_) {},
      onReorderSets: (_) {},
      onChangeSetType: onChangeSetType,
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

  testWidgets('a row shows a non-working set\'s type, and only that one', (tester) async {
    await _pump(tester, _editor(sets: const [_warmupRow, _workingRow]));

    expect(find.byKey(const ValueKey('set_editor_type_s1')), findsOneWidget);
    expect(find.text('WARM-UP'), findsOneWidget);
    expect(find.byKey(const ValueKey('set_editor_type_s2')), findsNothing);
  });

  testWidgets('a set\'s type changes from the menu beside its row', (tester) async {
    final changes = <(String, SetType)>[];
    await _pump(tester, _editor(sets: const [_warmupRow, _workingRow], onChangeSetType: (id, t) => changes.add((id, t))));

    await tester.tap(find.byKey(const ValueKey('set_editor_type_menu_s2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cool-down').last);
    await tester.pumpAndSettle();
    expect(changes, [('s2', SetType.cooldown)]);

    // Picking the type it already has changes nothing.
    await tester.tap(find.byKey(const ValueKey('set_editor_type_menu_s1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Warm-up').last);
    await tester.pumpAndSettle();
    expect(changes, hasLength(1));
  });

  testWidgets('the menu is announced as "Set type" and is absent without a handler', (tester) async {
    await _pump(tester, _editor(sets: const [_workingRow], onChangeSetType: (_, _) {}));
    expect(find.byTooltip('Set type'), findsOneWidget);

    await _pump(tester, _editor(sets: const [_workingRow]));
    expect(find.byTooltip('Set type'), findsNothing);
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
        _editor(sets: const [pctRow], onChangeSetType: (_, _) {}),
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
        _editor(sets: const [pctRow], onChangeSetType: (_, _) {}),
        size: const Size(900, 700),
        oneRepMaxes: const {'e1': OneRepMax.measured(100)},
      );

      final prescription = tester.getCenter(find.text('60% of 1RM'));
      final load = tester.getCenter(find.byKey(const ValueKey('set_editor_resolved_p1')));
      expect((load.dy - prescription.dy).abs(), lessThan(4));
      expect(load.dx, greaterThan(prescription.dx));
    });
  });
}
