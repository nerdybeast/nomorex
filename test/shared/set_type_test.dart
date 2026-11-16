import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/programs/models/program_set.dart';
import 'package:nomorex/features/workouts/models/workout_set.dart';
import 'package:nomorex/shared/models/set_type.dart';

void main() {
  group('SetType.fromDb', () {
    test('reads each stored value', () {
      expect(SetType.fromDb('warmup'), SetType.warmup);
      expect(SetType.fromDb('working'), SetType.working);
      expect(SetType.fromDb('cooldown'), SetType.cooldown);
    });

    test('reads a missing or unknown value as a working set', () {
      expect(SetType.fromDb(null), SetType.working);
      // A type added on the server after this app shipped.
      expect(SetType.fromDb('dropset'), SetType.working);
    });
  });

  test('set models read set_type, defaulting to working', () {
    final base = {
      'id': 's1',
      'position': 0,
      'weight_mode': 'absolute',
      'target_reps': 5,
      'absolute_weight_kg': 60,
    };
    expect(WorkoutSet.fromJson({...base, 'workout_exercise_id': 'we', 'set_type': 'warmup'}).setType, SetType.warmup);
    expect(WorkoutSet.fromJson({...base, 'workout_exercise_id': 'we'}).setType, SetType.working);
    expect(ProgramSet.fromJson({...base, 'program_exercise_id': 'pe', 'set_type': 'cooldown'}).setType,
        SetType.cooldown);
    // toEditableRow carries it to the shared editor.
    expect(
      ProgramSet.fromJson({...base, 'program_exercise_id': 'pe', 'set_type': 'cooldown'}).toEditableRow().setType,
      SetType.cooldown,
    );
  });

  group('countedSets', () {
    SetType typeOf(SetType t) => t;

    test('counts only the working sets', () {
      final sets = [SetType.warmup, SetType.warmup, SetType.working, SetType.working, SetType.cooldown];
      expect(countedSets(sets, typeOf), [SetType.working, SetType.working]);
    });

    test('counts every set when there are no working sets, so it is never 0/0', () {
      final sets = [SetType.warmup, SetType.cooldown];
      expect(countedSets(sets, typeOf), sets);
    });

    test('an empty list stays empty', () {
      expect(countedSets(const <SetType>[], typeOf), isEmpty);
    });
  });
}
