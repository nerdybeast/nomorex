import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/personal_bests/models/personal_best.dart';
import 'package:nomorex/features/personal_bests/utils/recent_prs.dart';

PersonalBest _pr(
  String id,
  String exerciseId,
  DateTime date, {
  DateTime? savedAt,
}) =>
    PersonalBest(
      id: id,
      userId: 'u1',
      exerciseId: exerciseId,
      exerciseName: exerciseId,
      weightKg: 100,
      reps: 1,
      date: date,
      updatedAt: savedAt ?? date,
    );

void main() {
  test('picks each lift\'s entry by PR date, not save time', () {
    // The 2022 entry was back-filled today, so it was saved last.
    final latest = latestPrPerExercise([
      _pr('backfilled', 'clean', DateTime(2022, 10, 19), savedAt: DateTime(2026, 11, 2)),
      _pr('current', 'clean', DateTime(2026, 11, 1), savedAt: DateTime(2026, 11, 1)),
    ]);

    expect(latest.map((p) => p.id), ['current']);
  });

  test('orders lifts by their current entry\'s date, newest first', () {
    final latest = latestPrPerExercise([
      _pr('squat', 'squat', DateTime(2026, 3, 1), savedAt: DateTime(2026, 11, 2)),
      _pr('clean', 'clean', DateTime(2026, 10, 1), savedAt: DateTime(2026, 10, 1)),
      _pr('row', 'row', DateTime(2026, 6, 1)),
    ]);

    expect(latest.map((p) => p.id), ['clean', 'row', 'squat']);
  });

  test('two entries on the same day: the later save wins', () {
    final day = DateTime(2026, 5, 1);
    final latest = latestPrPerExercise([
      _pr('first', 'squat', day, savedAt: DateTime(2026, 5, 1, 9)),
      _pr('second', 'squat', day, savedAt: DateTime(2026, 5, 1, 18)),
    ]);

    expect(latest.single.id, 'second');
  });
}
