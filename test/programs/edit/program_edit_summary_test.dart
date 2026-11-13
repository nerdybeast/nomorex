import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/programs/models/program_exercise.dart';
import 'package:nomorex/features/programs/models/program_set.dart';
import 'package:nomorex/features/programs/models/program_week.dart';
import 'package:nomorex/features/programs/utils/program_edit_summary.dart';

ProgramExercise _ex(List<ProgramSet> sets, {String name = 'Snatch Pull'}) =>
    ProgramExercise(id: 'pe', programDayId: 'd', exerciseId: 'e', exerciseName: name, position: 0, sets: sets);

ProgramSet _abs(int reps, double kg) =>
    ProgramSet(id: 's', programExerciseId: 'pe', position: 0, weightMode: 'absolute', targetReps: reps, absoluteWeightKg: kg);

ProgramSet _pct(int reps, double pct, {double? max, String? basisId, String? basisName}) => ProgramSet(
      id: 's',
      programExerciseId: 'pe',
      position: 0,
      weightMode: 'percentage',
      targetReps: reps,
      percentage: pct,
      percentageMax: max,
      basisExerciseId: basisId,
      basisExerciseName: basisName,
    );

ProgramSet _open(int reps) =>
    ProgramSet(id: 's', programExerciseId: 'pe', position: 0, weightMode: 'open', targetReps: reps);

void main() {
  test('sets read "N × reps" when every set shares its reps, else "N sets"', () {
    expect(exerciseSetsSummary(_ex([_abs(3, 20), _abs(3, 20), _abs(3, 20), _abs(3, 20)])), '4 × 3');
    expect(exerciseSetsSummary(_ex([_abs(5, 20), _abs(3, 20)])), '2 sets');
    expect(exerciseSetsSummary(_ex([])), 'No sets');
  });

  test('a fixed load reads as a weight, or a range when the sets differ', () {
    expect(exerciseLoadSummary(_ex([_abs(3, 20), _abs(3, 20)]), 'kg'), '20 kg');
    expect(exerciseLoadSummary(_ex([_abs(3, 60), _abs(3, 80)]), 'kg'), '60–80 kg');
  });

  test('percentages stay percentages: single, wave and range', () {
    expect(exerciseLoadSummary(_ex([_pct(1, 80), _pct(1, 80)]), 'kg'), '80%');
    expect(exerciseLoadSummary(_ex([_pct(1, 70), _pct(1, 90)]), 'kg'), '70–90%');
    expect(exerciseLoadSummary(_ex([_pct(3, 67, max: 72.5)]), 'kg'), '67–72.5%');
  });

  test('names the basis lift when it is another exercise', () {
    expect(
      exerciseLoadSummary(_ex([_pct(1, 100, basisId: 'sn', basisName: 'Snatch')]), 'kg'),
      '100% of Snatch',
    );
  });

  test('open load says "choose load", and mixed kinds say so', () {
    expect(exerciseLoadSummary(_ex([_open(8)]), 'kg'), 'choose load');
    expect(exerciseLoadSummary(_ex([_open(8), _abs(8, 20)]), 'kg'), 'mixed loads');
    expect(exerciseLoadSummary(_ex([]), 'kg'), isNull);
  });

  test('an exercise on one line', () {
    expect(exerciseLine(_ex([_abs(3, 85), _abs(3, 85), _abs(3, 85)]), 'kg'), '3 × 3 · 85 kg');
  });

  test('week titles include the label when there is one', () {
    ProgramWeek week(String? label) =>
        ProgramWeek(id: 'w', programId: 'p', weekNumber: 1, position: 0, label: label, days: const []);
    expect(weekTitle(week('Meso 1/4')), 'Week 1 · Meso 1/4');
    expect(weekTitle(week(null)), 'Week 1');
    expect(weekTitle(week('  ')), 'Week 1');
  });
}
