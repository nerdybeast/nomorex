import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/workouts/models/workout.dart';
import 'package:nomorex/features/workouts/models/workout_set.dart';

void main() {
  test('Workout.fromJson parses nested exercises and sets', () {
    final json = {
      'id': 'w1',
      'user_id': 'u1',
      'title': 'Day 1',
      'date': '2026-06-28',
      'updated_at': '2026-06-29T12:00:00Z',
      'notes': null,
      'workout_exercises': [
        {
          'id': 'we1',
          'workout_id': 'w1',
          'exercise_id': 'e1',
          'position': 0,
          'notes': 'build to a heavy triple',
          'exercises': {'name': 'Snatch'},
          'workout_sets': [
            {
              'id': 's1',
              'workout_exercise_id': 'we1',
              'position': 0,
              'target_reps': 5,
              'weight_mode': 'percentage',
              'percentage': 80,
              'absolute_weight_kg': null,
              'note': null,
              'completed': false,
              'actual_weight_kg': null,
              'actual_reps': null,
            },
          ],
        },
      ],
    };

    final w = Workout.fromJson(json);
    expect(w.title, 'Day 1');
    expect(w.date.year, 2026);
    expect(w.exercises.single.exerciseName, 'Snatch');
    final s = w.exercises.single.sets.single;
    expect(s.weightMode, 'percentage');
    expect(s.percentage, 80);
    expect(s.targetReps, 5);
  });

  test('Workout.fromJson tolerates missing nested collections', () {
    final w = Workout.fromJson({
      'id': 'w1',
      'user_id': 'u1',
      'title': 'Empty',
      'date': '2026-06-28',
      'updated_at': '2026-06-28T00:00:00Z',
    });
    expect(w.exercises, isEmpty);
    expect(w.isPublic, isFalse);
  });

  test('Workout.fromJson parses is_public', () {
    final w = Workout.fromJson({
      'id': 'w1',
      'user_id': 'u1',
      'title': 'Public workout',
      'date': '2026-06-28',
      'updated_at': '2026-06-28T00:00:00Z',
      'is_public': true,
    });
    expect(w.isPublic, isTrue);
  });

  test('Workout.fromJson parses updated_at', () {
    final w = Workout.fromJson({
      'id': 'w1',
      'user_id': 'u1',
      'title': 'Day 1',
      'date': '2026-06-28',
      'updated_at': '2026-07-02T08:30:00Z',
    });
    expect(w.updatedAt, DateTime.parse('2026-07-02T08:30:00Z'));
  });

  test('WorkoutSet.fromJson parses basis_exercise_id and its joined name', () {
    final s = WorkoutSet.fromJson({
      'id': 's1',
      'workout_exercise_id': 'we1',
      'position': 0,
      'weight_mode': 'percentage',
      'percentage': 85,
      'basis_exercise_id': 'e2',
      'exercises': {'name': 'Clean and Jerk'},
    });
    expect(s.basisExerciseId, 'e2');
    expect(s.basisExerciseName, 'Clean and Jerk');
  });

  test('WorkoutSet.fromJson tolerates a missing basis_exercise_id/join', () {
    final s = WorkoutSet.fromJson({
      'id': 's1',
      'workout_exercise_id': 'we1',
      'position': 0,
      'weight_mode': 'absolute',
      'absolute_weight_kg': 60,
    });
    expect(s.basisExerciseId, isNull);
    expect(s.basisExerciseName, isNull);
  });
}
