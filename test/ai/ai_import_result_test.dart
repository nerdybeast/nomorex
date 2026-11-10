import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/ai/models/ai_import_result.dart';
import 'package:nomorex/features/exercises/models/exercise.dart';

import 'ai_import_review_fixtures.dart';

void main() {
  group('AiImportResult', () {
    test('reads a workout', () {
      final r = AiImportResult.fromJson(workoutResult());
      expect(r.isProgram, isFalse);
      expect(r.title, 'Lower body A');
      expect(r.handwritten, isTrue);
      expect(r.exercises.map((e) => e.name), ['Front Squat', 'Romanian Deadlift', 'Bench', '2 Hang Clean + 1 Jerk']);
      expect(r.unstructured.single.originalText, 'Walking lunge 3 x 12 light by feel');
      final combo = r.exercises.last.sets.single;
      expect(combo.reps, isNull);
      expect(combo.unreadable, ['reps']);
    });

    test('needs a unit only for an absolute weight printed without one', () {
      expect(AiImportResult.fromJson(workoutResult()).needsUnit, isTrue);
      expect(AiImportResult.fromJson(programResult()).needsUnit, isFalse, reason: 'all percentages');
    });

    test('lists each name to check once, counting basis lifts', () {
      final toCheck = AiImportResult.fromJson(workoutResult()).exercisesToCheck;
      expect(toCheck.map((c) => (c.name, c.occurrences)), [('2 Hang Clean + 1 Jerk', 2), ('Bench', 1)]);
      expect(toCheck.last.match?.name, 'Bench Press');
    });

    test('counts a name across a program\'s weeks', () {
      final toCheck = AiImportResult.fromJson(programResult(weeks: 3)).exercisesToCheck;
      expect(toCheck.single.name, 'Pause squat');
      expect(toCheck.single.occurrences, 3);
    });
  });

  group('buildReviewedPayload', () {
    Map<String, dynamic> exerciseNamed(Map<String, dynamic> payload, String name, {int week = 0, int day = 0}) =>
        ((payload['weeks'] as List)[week]['days'] as List)[day]['exercises'].firstWhere((e) => e['name'] == name)
            as Map<String, dynamic>;

    test('converts each absolute load to weightKg, keeping a printed unit', () {
      final out = buildReviewedPayload(workoutResult(), title: 'x', fixes: const {}, unit: 'kg');
      final rdl = exerciseNamed(out, 'Romanian Deadlift')['sets'][0] as Map;
      expect(rdl['weightKg'], 100);
      expect(rdl.containsKey('weight'), isFalse);
      expect(rdl.containsKey('unit'), isFalse);

      final bench = exerciseNamed(out, 'Bench')['sets'][0] as Map;
      expect(bench['weightKg'], 102.058, reason: 'printed lb stays lb even though the choice was kg');
    });

    test('applies the chosen unit to unlabelled weights', () {
      final out = buildReviewedPayload(workoutResult(), title: 'x', fixes: const {}, unit: 'lb');
      expect(exerciseNamed(out, 'Romanian Deadlift')['sets'][0]['weightKg'], 45.359);
    });

    test('refuses an unlabelled weight with no unit chosen', () {
      expect(() => buildReviewedPayload(workoutResult(), title: 'x', fixes: const {}), throwsStateError);
    });

    test('leaves percentage sets alone', () {
      final out = buildReviewedPayload(programResult(), title: 'x', fixes: const {});
      final set = exerciseNamed(out, 'Back Squat')['sets'][0] as Map;
      expect(set, {'sets': 5, 'reps': 5, 'percent': 70});
    });

    test('a fix applies to every occurrence, including basis lifts', () {
      const custom = CreateCustomExercise('Hang Clean + Jerk complex');
      final out = buildReviewedPayload(
        workoutResult(),
        title: 'x',
        fixes: {
          exerciseKey('2 hang clean + 1 jerk'): custom,
          exerciseKey('Bench'): const UseExistingExercise(
            Exercise(id: 'ex-bp', name: 'Bench Press', isPredefined: true),
          ),
        },
        unit: 'kg',
      );
      final exercises = (out['weeks'] as List)[0]['days'][0]['exercises'] as List;
      final combo = exercises[3] as Map;
      expect(combo['name'], 'Hang Clean + Jerk complex');
      expect(combo['match'], isNull);
      expect(combo['notes'], 'Combination: 2 hang cleans then 1 jerk', reason: 'the rest is untouched');
      expect(exercises[0]['sets'][0]['basisExercise'], {'name': 'Hang Clean + Jerk complex', 'match': null});
      expect(exercises[2]['match'], {'exerciseId': 'ex-bp', 'name': 'Bench Press', 'confidence': 'exact'});
    });

    test('a fix reaches every week of a program', () {
      final out = buildReviewedPayload(
        programResult(weeks: 3),
        title: 'x',
        fixes: {
          'pause squat': const UseExistingExercise(Exercise(id: 'ex-bs', name: 'Back Squat', isPredefined: true)),
        },
      );
      for (var w = 0; w < 3; w++) {
        expect(exerciseNamed(out, 'Pause squat', week: w)['match']['exerciseId'], 'ex-bs');
      }
      expect((out['weeks'] as List)[0]['days'][1]['isRestDay'], isTrue, reason: 'rest days are kept');
    });

    test('a blank title leaves the server to name it', () {
      expect(buildReviewedPayload(programResult(), title: '  ', fixes: const {})['title'], isNull);
      expect(buildReviewedPayload(programResult(), title: ' Mine ', fixes: const {})['title'], 'Mine');
    });

    test('keeps fields it doesn\'t know about', () {
      final out = buildReviewedPayload(workoutResult(), title: 'x', fixes: const {}, unit: 'kg');
      expect(out['unstructured'], workoutResult()['unstructured']);
      expect(out['schemaVersion'], 1);
    });
  });
}
