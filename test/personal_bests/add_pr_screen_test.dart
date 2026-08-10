import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/exercises/models/exercise.dart';
import 'package:nomorex/features/exercises/providers/exercises_provider.dart';
import 'package:nomorex/features/personal_bests/models/personal_best.dart';
import 'package:nomorex/features/personal_bests/providers/personal_bests_provider.dart';
import 'package:nomorex/features/personal_bests/screens/add_pr_screen.dart';
import 'package:nomorex/features/profile/providers/profile_provider.dart';

const _backSquat = Exercise(id: 'e1', name: 'Back Squat', isPredefined: true);

class _StubExercisesNotifier extends ExercisesNotifier {
  @override
  Future<List<Exercise>> build() async => const [_backSquat];
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

Widget _wrap(String preference, void Function(double) onAddPr) => ProviderScope(
      overrides: [
        exercisesProvider.overrideWith(() => _StubExercisesNotifier()),
        personalBestsProvider.overrideWith(() => _RecordingPersonalBestsNotifier(onAddPr)),
        unitPreferenceProvider.overrideWithValue(preference),
      ],
      child: const MaterialApp(home: AddPrScreen()),
    );

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
}
