// Ported from supabase/functions/ai/ai_import/prompt_test.ts.
import 'package:import_pipeline/import_pipeline.dart';
import 'package:test/test.dart';

void main() {
  test('the catalog lists active exercises with their aliases, and leaves retired ones out', () {
    expect(
      catalogLines(const [
        CatalogExercise(id: 'cj', name: 'Clean & Jerk', aliases: ['C&J', 'Clean and Jerk'], isPredefined: true),
        CatalogExercise(id: 'sq', name: 'Back Squat', isPredefined: true),
        CatalogExercise(id: 'old', name: 'Old Lift', isPredefined: true, retiredAt: '2026-11-01T00:00:00Z'),
        CatalogExercise(id: 'mine', name: 'Dude Pulls'),
      ]),
      ['Clean & Jerk (also: C&J, Clean and Jerk)', 'Back Squat', 'Dude Pulls'],
    );
  });

  test('the prompt asks for a description, copied or else written and marked', () {
    for (final phrase in ['"description": string', '"descriptionGenerated": true', 'at most 200 characters']) {
      expect(kImportSystemPrompt, contains(phrase));
    }
  });

  test('the user prompt lists the catalog and passes on a requested type', () {
    expect(buildImportUserPrompt(['Back Squat', 'Snatch']), startsWith('Exercise catalog:\nBack Squat\nSnatch\n\n'));
    expect(buildImportUserPrompt(['Back Squat'], ImportType.program), startsWith('The user has said this file is a program.'));
  });

  test('a catalog row from Supabase reads with its aliases', () {
    final e = CatalogExercise.fromJson({
      'id': 'cj',
      'name': 'Clean & Jerk',
      'aliases': ['C&J'],
      'is_predefined': true,
      'retired_at': null,
      'created_at': '2026-01-01T00:00:00Z',
    });
    expect([e.name, e.aliases, e.isPredefined, e.retiredAt], ['Clean & Jerk', ['C&J'], true, null]);
  });
}
