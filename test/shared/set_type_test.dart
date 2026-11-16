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

  group('placeByType', () {
    List<String> place(List<(String, SetType)> sets, List<String> newIds, SetType type) =>
        placeByType(sets, idOf: (s) => s.$1, typeOf: (s) => s.$2, newIds: newIds, type: type);

    test('a warm-up added after the working sets lands above them', () {
      expect(
        place([('w1', SetType.working), ('w2', SetType.working), ('n', SetType.warmup)], ['n'], SetType.warmup),
        ['n', 'w1', 'w2'],
      );
    });

    test('it goes after the warm-ups already there', () {
      expect(
        place(
          [('u1', SetType.warmup), ('w1', SetType.working), ('c1', SetType.cooldown), ('n1', SetType.warmup), ('n2', SetType.warmup)],
          ['n1', 'n2'],
          SetType.warmup,
        ),
        ['u1', 'n1', 'n2', 'w1', 'c1'],
      );
    });

    test('a working set added after a cool-down goes before it', () {
      expect(
        place([('w1', SetType.working), ('c1', SetType.cooldown), ('n', SetType.working)], ['n'], SetType.working),
        ['w1', 'n', 'c1'],
      );
    });

    test('a cool-down stays at the end, and nothing else moves', () {
      final sets = [('u1', SetType.warmup), ('w1', SetType.working), ('n', SetType.cooldown)];
      expect(place(sets, ['n'], SetType.cooldown), ['u1', 'w1', 'n']);
    });

    test('the first set of an exercise stays first', () {
      expect(place([('n', SetType.warmup)], ['n'], SetType.warmup), ['n']);
    });
  });
}
