import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/programs/models/program_set.dart';
import 'package:nomorex/features/programs/utils/program_day_brief.dart';
import 'package:nomorex/shared/models/set_type.dart';

ProgramSet _set(int i, {int reps = 3, double? pct, String mode = 'percentage', String? basis, SetType type = SetType.working}) =>
    ProgramSet(
      id: 's$i',
      programExerciseId: 'pe',
      position: i,
      weightMode: mode,
      targetReps: reps,
      percentage: pct,
      basisExerciseId: basis,
      setType: type,
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

  test('a warm-up never joins the identical working sets after it', () {
    final groups = groupConsecutiveSets([
      _set(0, pct: 70, type: SetType.warmup),
      _set(1, pct: 70),
      _set(2, pct: 70),
      _set(3, pct: 70, type: SetType.cooldown),
    ]);
    expect(groups.map((g) => (g.first.setType, g.count)), [
      (SetType.warmup, 1),
      (SetType.working, 2),
      (SetType.cooldown, 1),
    ]);
  });

  test('rep ranges read as a range', () {
    expect(repsNumber(8, 12), '8–12');
    expect(repsNumber(5, 5), '5');
    expect(repsNumber(null, null), '?');
  });
}
