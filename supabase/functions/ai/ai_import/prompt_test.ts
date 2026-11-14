import { assertEquals } from 'jsr:@std/assert@1';
import { catalogLines } from './prompt.ts';

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
