import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/exercises/providers/recent_exercises_provider.dart';

void main() {
  test('newest first, each lift once, across workouts and programs', () {
    final rows = [
      (exerciseId: 'squat', createdAt: DateTime(2026, 11, 1)),
      (exerciseId: 'snatch', createdAt: DateTime(2026, 11, 10)),
      (exerciseId: 'squat', createdAt: DateTime(2026, 11, 9)),
      (exerciseId: 'bench', createdAt: DateTime(2026, 11, 5)),
    ];
    expect(mostRecentExerciseIds(rows), ['snatch', 'squat', 'bench']);
  });

  test('caps the list', () {
    final rows = [
      for (var i = 0; i < 20; i++) (exerciseId: 'e$i', createdAt: DateTime(2026, 1, 1 + i)),
    ];
    expect(mostRecentExerciseIds(rows, limit: 3), ['e19', 'e18', 'e17']);
  });
}
