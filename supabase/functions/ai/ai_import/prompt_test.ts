import { assertEquals } from 'jsr:@std/assert@1';
import { catalogLines, SYSTEM_PROMPT } from './prompt.ts';

Deno.test('the catalog lists active exercises with their aliases, and leaves retired ones out', () => {
  assertEquals(
    catalogLines([
      { id: 'cj', name: 'Clean & Jerk', aliases: ['C&J', 'Clean and Jerk'], is_predefined: true },
      { id: 'sq', name: 'Back Squat', aliases: [], is_predefined: true },
      { id: 'old', name: 'Old Lift', is_predefined: true, retired_at: '2026-11-01T00:00:00Z' },
      { id: 'mine', name: 'Dude Pulls', is_predefined: false },
    ]),
    ['Clean & Jerk (also: C&J, Clean and Jerk)', 'Back Squat', 'Dude Pulls'],
  );
});

Deno.test('the prompt asks for a description, copied or else written and marked', () => {
  for (const phrase of ['"description": string', '"descriptionGenerated": true', 'at most 200 characters']) {
    if (!SYSTEM_PROMPT.includes(phrase)) throw new Error(`prompt is missing ${phrase}`);
  }
});
