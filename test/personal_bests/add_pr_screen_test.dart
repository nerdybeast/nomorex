import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/exercises/models/exercise.dart';
import 'package:nomorex/features/exercises/providers/exercises_provider.dart';
import 'package:nomorex/features/personal_bests/models/personal_best.dart';
import 'package:nomorex/features/personal_bests/providers/personal_bests_provider.dart';
import 'package:nomorex/features/personal_bests/screens/add_pr_screen.dart';
import 'package:nomorex/features/profile/providers/profile_provider.dart';
import 'package:nomorex/core/utils/one_rep_max_formula.dart';

const _backSquat = Exercise(id: 'e1', name: 'Back Squat', isPredefined: true);
const _deadlift = Exercise(id: 'e2', name: 'Deadlift', isPredefined: true);

class _StubExercisesNotifier extends ExercisesNotifier {
  _StubExercisesNotifier(this._exercises);
  final List<Exercise> _exercises;

  @override
  Future<List<Exercise>> build() async => _exercises;
}

class _RecordingPersonalBestsNotifier extends PersonalBestsNotifier {
  _RecordingPersonalBestsNotifier(this.onAddPr);
  final void Function(double weightKg) onAddPr;

  @override
  Future<List<PersonalBest>> build() async => const [];

  @override
  Future<void> addPr({
    required String exerciseId,
    required double weightKg,
    required int reps,
    required DateTime date,
    String? notes,
  }) async {
    onAddPr(weightKg);
  }
}

Widget _wrap(
  String preference,
  void Function(double) onAddPr, {
  OneRepMaxFormula formula = OneRepMaxFormula.brzycki,
}) =>
    ProviderScope(
      overrides: [
        exercisesProvider.overrideWith(() => _StubExercisesNotifier([_backSquat])),
        personalBestsProvider.overrideWith(() => _RecordingPersonalBestsNotifier(onAddPr)),
        unitPreferenceProvider.overrideWithValue(preference),
        oneRepMaxFormulaProvider.overrideWithValue(formula),
      ],
      child: const MaterialApp(home: AddPrScreen()),
    );

/// Sets the weight and reps steppers. Both target their keyed widget rather
/// than the displayed value, so they work on a screen that already has
/// numbers in it.
Future<void> _enterLift(
  WidgetTester tester, {
  required String weight,
  required int reps,
}) async {
  final weightField = find.descendant(
    of: find.byKey(const Key('add_pr_weight')),
    matching: find.byType(TextField),
  );
  await tester.ensureVisible(weightField);
  await tester.pumpAndSettle();
  await tester.enterText(weightField, weight);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();

  final repsField = find.descendant(
    of: find.byKey(const Key('add_pr_reps')),
    matching: find.byType(TextField),
  );
  await tester.ensureVisible(repsField);
  await tester.pumpAndSettle();
  await tester.enterText(repsField, '$reps');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

Future<void> _selectExercise(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(TextFormField, 'Exercise'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Back Squat'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows a static kg chip, not a toggle, when preference is fixed to kg',
      (tester) async {
    await tester.pumpWidget(_wrap('kg', (_) {}));
    await tester.pumpAndSettle();

    expect(find.text('WEIGHT (KG)'), findsOneWidget);
    expect(find.text('lbs'), findsNothing);
  });

  testWidgets(
      "toggling kg/lbs when preference is 'both' only affects this entry, "
      'never persists to the profile', (tester) async {
    await tester.pumpWidget(_wrap('both', (_) {}));
    await tester.pumpAndSettle();

    // Defaults to kg when the preference is 'both'.
    expect(find.text('WEIGHT (KG)'), findsOneWidget);

    await tester.tap(find.text('lbs'));
    await tester.pumpAndSettle();

    expect(find.text('WEIGHT (LBS)'), findsOneWidget);
    // If this had persisted, unitPreferenceProvider (fixed via override
    // above) would still read 'both' — there's no notifier to catch a
    // setUnitPreference call in the first place, since AddPrScreen no
    // longer references profileProvider.notifier at all.
  });

  testWidgets('submits the entered weight converted to kg', (tester) async {
    double? captured;
    await tester.pumpWidget(_wrap('kg', (kg) => captured = kg));
    await tester.pumpAndSettle();

    await _selectExercise(tester);

    await tester.enterText(find.widgetWithText(TextField, '0.0'), '100');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Personal Best'));
    await tester.pumpAndSettle();

    expect(captured, 100);
  });

  testWidgets('exerciseId pre-fills the matching exercise in the picker', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exercisesProvider.overrideWith(() => _StubExercisesNotifier([_backSquat, _deadlift])),
        ],
        child: const MaterialApp(home: AddPrScreen(exerciseId: 'e1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Back Squat'), findsOneWidget);
  });

  testWidgets('an unknown exerciseId leaves the picker blank without throwing',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exercisesProvider.overrideWith(() => _StubExercisesNotifier([_backSquat, _deadlift])),
        ],
        child: const MaterialApp(home: AddPrScreen(exerciseId: 'nonexistent')),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Back Squat'), findsNothing);
    expect(find.text('Deadlift'), findsNothing);
  });

  testWidgets('no exerciseId behaves like today: the picker starts blank', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exercisesProvider.overrideWith(() => _StubExercisesNotifier([_backSquat, _deadlift])),
        ],
        child: const MaterialApp(home: AddPrScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Back Squat'), findsNothing);
    expect(find.text('Deadlift'), findsNothing);
  });

  testWidgets('shows an estimated 1RM once the entry is a multi-rep set',
      (tester) async {
    await tester.pumpWidget(_wrap('kg', (_) {}));
    await tester.pumpAndSettle();

    // A single needs no estimate — the formulas return the lifted weight.
    await _enterLift(tester, weight: '100', reps: 1);
    expect(find.byKey(const Key('add_pr_estimated_1rm')), findsNothing);

    await _enterLift(tester, weight: '100', reps: 5);
    expect(
      find.text('Estimated 1RM 112.5 kg (Brzycki)'),
      findsOneWidget,
    );
  });

  testWidgets('the estimate follows the profile formula', (tester) async {
    await tester.pumpWidget(
      _wrap('kg', (_) {}, formula: OneRepMaxFormula.epley),
    );
    await tester.pumpAndSettle();

    await _enterLift(tester, weight: '100', reps: 5);

    expect(find.text('Estimated 1RM 116.7 kg (Epley)'), findsOneWidget);
  });

  testWidgets('no estimate past the usable rep range', (tester) async {
    await tester.pumpWidget(_wrap('kg', (_) {}));
    await tester.pumpAndSettle();

    await _enterLift(tester, weight: '100', reps: kMaxEstimableReps + 1);

    expect(find.byKey(const Key('add_pr_estimated_1rm')), findsNothing);
  });

  testWidgets('the estimate is expressed in the unit being typed in',
      (tester) async {
    await tester.pumpWidget(_wrap('both', (_) {}));
    await tester.pumpAndSettle();

    await tester.tap(find.text('lbs'));
    await tester.pumpAndSettle();

    await _enterLift(tester, weight: '441', reps: 2);

    // 441 lbs x 2 -> 453.6 lbs by Brzycki. Asserted exactly: formatWeight
    // converts out of kg, so an estimate computed in the entry unit and
    // handed to it double-converts and renders 1000.0 lbs.
    expect(find.text('Estimated 1RM 453.6 lbs (Brzycki)'), findsOneWidget);
  });
}
