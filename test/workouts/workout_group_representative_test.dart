import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/workouts/models/workout.dart';
import 'package:nomorex/features/workouts/utils/workout_group_representative.dart';

Workout _workout({
  required String id,
  required String status,
  DateTime? finishedAt,
  DateTime? updatedAt,
}) {
  final date = DateTime(2026, 8, 1);
  return Workout(
    id: id,
    userId: 'u1',
    title: 'Workout',
    date: date,
    updatedAt: updatedAt ?? date,
    workoutGroupId: 'g1',
    status: status,
    finishedAt: finishedAt,
  );
}

void main() {
  test('an in-progress row wins over a not-started row', () {
    final inProgress = _workout(id: 'w1', status: 'in_progress');
    final notStarted = _workout(id: 'w2', status: 'not_started');

    expect(pickGroupRepresentative([notStarted, inProgress])?.id, 'w1');
  });

  test('a paused row wins over a not-started row', () {
    final paused = _workout(id: 'w1', status: 'paused');
    final notStarted = _workout(id: 'w2', status: 'not_started');

    expect(pickGroupRepresentative([notStarted, paused])?.id, 'w1');
  });

  test('a not-started row wins over finished rows', () {
    final notStarted = _workout(id: 'w1', status: 'not_started');
    final finished = _workout(
      id: 'w2',
      status: 'finished',
      finishedAt: DateTime(2026, 8, 5),
    );

    expect(pickGroupRepresentative([finished, notStarted])?.id, 'w1');
  });

  test('when every row is finished, the most recently finished one wins', () {
    final older = _workout(id: 'w1', status: 'finished', finishedAt: DateTime(2026, 8, 1));
    final newer = _workout(id: 'w2', status: 'finished', finishedAt: DateTime(2026, 8, 10));
    final middle = _workout(id: 'w3', status: 'finished', finishedAt: DateTime(2026, 8, 5));

    expect(pickGroupRepresentative([older, newer, middle])?.id, 'w2');
  });

  test('returns null for an empty group', () {
    expect(pickGroupRepresentative(const []), isNull);
  });
}
