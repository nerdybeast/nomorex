import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/exercises/models/exercise.dart';
import 'package:nomorex/features/exercises/providers/exercises_provider.dart';
import 'package:nomorex/features/personal_bests/screens/add_pr_screen.dart';

const _squat = Exercise(id: 'e1', name: 'Back Squat', isPredefined: true);
const _deadlift = Exercise(id: 'e2', name: 'Deadlift', isPredefined: true);

class _StubExercisesNotifier extends ExercisesNotifier {
  _StubExercisesNotifier(this._exercises);
  final List<Exercise> _exercises;

  @override
  Future<List<Exercise>> build() async => _exercises;
}

void main() {
  testWidgets('exerciseId pre-fills the matching exercise in the picker', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exercisesProvider.overrideWith(() => _StubExercisesNotifier([_squat, _deadlift])),
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
          exercisesProvider.overrideWith(() => _StubExercisesNotifier([_squat, _deadlift])),
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
          exercisesProvider.overrideWith(() => _StubExercisesNotifier([_squat, _deadlift])),
        ],
        child: const MaterialApp(home: AddPrScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Back Squat'), findsNothing);
    expect(find.text('Deadlift'), findsNothing);
  });
}
