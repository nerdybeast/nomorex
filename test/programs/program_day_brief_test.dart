import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/programs/models/program_set.dart';
import 'package:nomorex/features/programs/utils/program_day_brief.dart';

ProgramSet _set(int i, {int reps = 3, double? pct, String mode = 'percentage', String? basis}) => ProgramSet(
      id: 's$i',
      programExerciseId: 'pe',
      position: i,
      weightMode: mode,
      targetReps: reps,
      percentage: pct,
      basisExerciseId: basis,
    );

void main() {
  test('identical consecutive sets collapse into one group, a wave keeps its steps', () {
    final groups = groupConsecutiveSets([
      _set(0, pct: 50), _set(1, pct: 60), _set(2, pct: 70), _set(3, pct: 70),
    ]);
    expect(groups.map(setGroupLabel), ['1 × 3', '1 × 3', '2 × 3']);
  });

  test('a change of reps, basis lift or mode starts a new group', () {
    final groups = groupConsecutiveSets([
      _set(0, pct: 70), _set(1, pct: 70, reps: 2), _set(2, pct: 70, reps: 2, basis: 'snatch'),
      _set(3, mode: 'open', pct: null), _set(4, mode: 'open', pct: null),
    ]);
    expect(groups.map((g) => g.count), [1, 1, 1, 2]);
  });

  test('rep ranges read as a range', () {
    expect(repsNumber(8, 12), '8–12');
    expect(repsNumber(5, 5), '5');
    expect(repsNumber(null, null), '?');
  });
}
