import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/exercises/models/exercise.dart';
import 'package:nomorex/features/exercises/utils/exercise_match.dart';

final _cj = Exercise(
  id: 'cj',
  name: 'Clean & Jerk',
  isPredefined: true,
  slug: 'clean_and_jerk',
  aliases: const ['C&J', 'Clean and Jerk'],
  createdAt: DateTime(2026, 1, 1),
);
final _retiredCj = Exercise(
  id: 'old-cj',
  name: 'Clean & Jerk',
  isPredefined: true,
  slug: 'old_clean_and_jerk',
  retiredAt: DateTime(2026, 6, 1),
  createdAt: DateTime(2025, 1, 1),
);
final _myCj = Exercise(id: 'my-cj', name: 'c&j', isPredefined: false, userId: 'u', createdAt: DateTime(2024, 1, 1));
final _myLiftNew = Exercise(id: 'new', name: 'Dude Pulls', isPredefined: false, userId: 'u', createdAt: DateTime(2026, 2, 1));
final _myLiftOld = Exercise(id: 'old', name: 'dude pulls', isPredefined: false, userId: 'u', createdAt: DateTime(2026, 1, 1));

void main() {
  group('findExerciseByName (the server\'s find_exercise_for_user order)', () {
    test('an alias finds the official exercise, normalized', () {
      expect(findExerciseByName([_cj], '  c&J ')?.id, 'cj');
      expect(findExerciseByName([_cj], 'CLEAN   and jerk')?.id, 'cj');
    });

    test('an active official exercise beats a retired one and a custom one', () {
      expect(findExerciseByName([_myCj, _retiredCj, _cj], 'c&j')?.id, 'cj');
      expect(findExerciseByName([_retiredCj, _cj], 'clean & jerk')?.id, 'cj');
    });

    test('a retired official exercise still beats a custom one', () {
      expect(findExerciseByName([_myCj, _retiredCj], 'Clean & Jerk')?.id, 'old-cj');
    });

    test('between custom exercises the oldest wins', () {
      expect(findExerciseByName([_myLiftNew, _myLiftOld], 'Dude Pulls')?.id, 'old');
    });

    test('no match, or a blank name, is null', () {
      expect(findExerciseByName([_cj], 'Snatch'), isNull);
      expect(findExerciseByName([_cj], '   '), isNull);
    });
  });

  test('exerciseMatchesQuery looks at the name and every alias', () {
    expect(exerciseMatchesQuery(_cj, 'jerk'), isTrue);
    expect(exerciseMatchesQuery(_cj, 'c&'), isTrue);
    expect(exerciseMatchesQuery(_cj, 'snatch'), isFalse);
    expect(exerciseMatchesQuery(_cj, ''), isTrue);
  });

  test('Exercise.fromJson reads the catalog columns', () {
    final e = Exercise.fromJson({
      'id': 'x',
      'name': 'Clean & Jerk',
      'is_predefined': true,
      'user_id': null,
      'slug': 'clean_and_jerk',
      'aliases': ['C&J'],
      'retired_at': '2026-11-01T00:00:00Z',
      'created_at': '2026-01-01T00:00:00Z',
    });
    expect(e.slug, 'clean_and_jerk');
    expect(e.aliases, ['C&J']);
    expect(e.isRetired, isTrue);
    expect(e.matchKeys, ['clean & jerk', 'c&j']);

    final custom = Exercise.fromJson({'id': 'y', 'name': 'Mine', 'is_predefined': false, 'user_id': 'u'});
    expect(custom.aliases, isEmpty);
    expect(custom.isRetired, isFalse);
  });
}
