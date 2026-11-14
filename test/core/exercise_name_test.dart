import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/core/utils/exercise_name.dart';

void main() {
  // The same cases as supabase/tests/database/exercise_catalog.test.sql and
  // supabase/functions/ai/ai_import/normalize_test.ts: the three copies of
  // the rule have to agree, or a name matched in one place misses in another.
  test('normalizeExerciseName matches the database and AI function rules', () {
    expect(normalizeExerciseName('  Clean   &  Jerk '), 'clean & jerk');
    expect(normalizeExerciseName('BACK\tSquat\n'), 'back squat');
    expect(normalizeExerciseName('Pull-Up'), 'pull-up');
    expect(normalizeExerciseName('   '), '');
  });
}
