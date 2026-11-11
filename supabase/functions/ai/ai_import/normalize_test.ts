import { assertEquals } from 'jsr:@std/assert@1';
import { type ImportResult, normalizeResult, parseModelJson } from './normalize.ts';

const CATALOG = [
  { id: 'squat', name: 'Back Squat' },
  { id: 'front', name: 'Front Squat' },
  { id: 'cj', name: 'Clean & Jerk' },
];

function workout(prescriptions: unknown[], exercise: Record<string, unknown> = {}) {
  return {
    type: 'workout',
    weeks: [{ days: [{ exercises: [{ name: 'Back Squat', prescriptions, ...exercise }] }] }],
  };
}

function ok(raw: unknown, requested?: 'workout' | 'program'): ImportResult {
  const out = normalizeResult(raw, CATALOG, requested);
  if (out.kind !== 'ok') throw new Error(`expected ok, got ${out.kind}`);
  return out.result;
}

const firstExercise = (r: ImportResult) => r.weeks[0].days[0].exercises[0];
const firstSet = (r: ImportResult) => firstExercise(r).sets[0];

Deno.test('keeps ranges, RPE and the printed unit', () => {
  const r = ok(workout([{
    sets: 3,
    reps: 7,
    repsMax: 9,
    percent: 67,
    percentMax: 72.5,
    rpeMin: 6,
    rpeMax: 7,
  }, { sets: 2, reps: 5, weight: 100, unit: 'lbs' }]));
  assertEquals(firstSet(r), {
    sets: 3,
    reps: 7,
    repsMax: 9,
    percent: 67,
    percentMax: 72.5,
    rpeMin: 6,
    rpeMax: 7,
  });
  assertEquals(firstExercise(r).sets[1], { sets: 2, reps: 5, weight: 100, unit: 'lb' });
  assertEquals(r.flags.needsUnit, false);
});

Deno.test('accepts loose values the model sometimes returns', () => {
  const r = ok(workout([{ sets: '3', reps: '5-8', percent: '67-72.5%', rpeMin: '6-7' }]));
  assertEquals(firstSet(r), {
    sets: 3,
    reps: 5,
    repsMax: 8,
    percent: 67,
    percentMax: 72.5,
    rpeMin: 6,
    rpeMax: 7,
  });
});

Deno.test('a weight with no real unit is left without one and flagged', () => {
  const r = ok(workout([{ sets: 3, reps: 5, weight: 100, unit: 'none' }]));
  assertEquals(firstSet(r), { sets: 3, reps: 5, weight: 100 });
  assertEquals(r.flags.needsUnit, true);
});

Deno.test('a range narrowed to one number is a single value, as the database stores it', () => {
  assertEquals(firstSet(ok(workout([{ sets: 1, reps: 5, repsMax: 5, percent: 70, percentMax: 70 }]))), {
    sets: 1,
    reps: 5,
    percent: 70,
  });
});

Deno.test('a set with no load is an open set, keeping its reps, RPE and wording', () => {
  const r = ok(workout([{ sets: 3, reps: 8, repsMax: 10, rpeMin: 8, note: 'light by feel' }]));
  assertEquals(firstExercise(r).sets, [
    { sets: 3, reps: 8, repsMax: 10, rpeMin: 8, openLoad: true, note: 'light by feel' },
  ]);
  assertEquals(r.unstructured, []);
  assertEquals(r.flags.unstructuredContent, false);
  assertEquals(r.flags.needsUnit, false);
});

Deno.test('"max reps" with no load is an open set with the wording as its note', () => {
  const r = ok(workout([{ sets: 3, note: 'max reps' }]));
  assertEquals(firstSet(r), { sets: 3, openLoad: true, note: 'max reps' });
  assertEquals(r.unstructured, []);
});

Deno.test('a set with no load, reps or wording is kept as flagged content, not dropped', () => {
  const r = ok(workout([{ sets: 3 }]));
  assertEquals(firstExercise(r).sets, []);
  assertEquals(r.unstructured[0].originalText, '3 sets');
  assertEquals(r.unstructured[0].location?.endsWith('Back Squat'), true);
});

Deno.test('a load marked unreadable is never an open set', () => {
  const r = ok(workout([{ sets: 3, reps: 5, unreadable: ['load'] }]));
  assertEquals(firstExercise(r).sets, []);
  assertEquals(r.unstructured[0].originalText, '3 x 5 (load could not be read)');
});

Deno.test('an open set has no basis lift', () => {
  const r = ok(workout([{ sets: 3, reps: 8, basisExercise: 'Clean & Jerk' }]));
  assertEquals(firstSet(r), { sets: 3, reps: 8, openLoad: true });
  assertEquals(r.flags.uncertainExercises, false);
});

Deno.test('an unreadable load goes to flagged content', () => {
  const r = ok(workout([{ sets: 3, reps: 5, weight: 'smudged' }]));
  assertEquals(firstExercise(r).sets, []);
  assertEquals(r.unstructured[0].originalText.includes('load could not be read'), true);
});

Deno.test('values that break the set rules become notes rather than failing the import', () => {
  const r = ok(workout([
    { sets: 3, reps: 8, repsMax: 5, percent: 70, rpeMin: 11 },
    { sets: 'lots', reps: 'AMRAP', percent: 70 },
  ]));
  assertEquals(firstSet(r), {
    sets: 3,
    reps: 8,
    percent: 70,
    note: 'Rep range top as printed: 5. RPE as printed: 11',
    unreadable: ['reps', 'rpe'],
  });
  assertEquals(firstExercise(r).sets[1], {
    sets: 1,
    percent: 70,
    note: 'Sets as printed: lots. Reps as printed: AMRAP',
    unreadable: ['sets', 'reps'],
  });
  assertEquals(r.flags.unreadableValues, true);
});

Deno.test('an inverted percentage range keeps the lower value and notes the printed one', () => {
  const set = firstSet(ok(workout([{ sets: 1, reps: 5, percent: 80, percentMax: 70 }])));
  assertEquals(set.percent, 80);
  assertEquals(set.percentMax, undefined);
  assertEquals(set.unreadable, ['load']);
});

Deno.test('a percentage wins over a printed load, which stays visible', () => {
  const set = firstSet(ok(workout([{ sets: 1, reps: 5, percent: 80, weight: 100, unit: 'kg' }])));
  assertEquals(set.percent, 80);
  assertEquals(set.weight, undefined);
  assertEquals(set.note, 'Printed load: 100kg');
});

Deno.test('keeps values the model flagged as unreadable', () => {
  const set = firstSet(ok(workout([{ sets: 3, percent: 70, unreadable: ['reps'] }])));
  assertEquals(set, { sets: 3, percent: 70, unreadable: ['reps'] });
});

Deno.test('flags a handwritten file only when the model says it is', () => {
  const body = workout([{ sets: 3, reps: 5, percent: 80 }]);
  assertEquals(ok({ ...body, handwritten: true }).flags.handwritten, true);
  assertEquals(ok(body).flags.handwritten, false);
  assertEquals(ok({ ...body, handwritten: 'maybe' }).flags.handwritten, false);
});

Deno.test('a name already in the catalog is an exact match, ignoring case and spaces', () => {
  const r = ok(workout([{ sets: 1, reps: 1, percent: 90 }], { name: '  back squat ', match: 'Front Squat' }));
  assertEquals(firstExercise(r).match, { exerciseId: 'squat', name: 'Back Squat', confidence: 'exact' });
  assertEquals(r.flags.uncertainExercises, false);
});

Deno.test('a suggested match carries the model confidence', () => {
  const high = ok(workout([{ sets: 1, reps: 1, percent: 90 }], {
    name: 'Pause FS',
    match: 'front squat',
    confidence: 'high',
  }));
  assertEquals(firstExercise(high).match, { exerciseId: 'front', name: 'Front Squat', confidence: 'high' });
  assertEquals(high.flags.uncertainExercises, false);

  const low = ok(workout([{ sets: 1, reps: 1, percent: 90 }], { name: 'FS', match: 'Front Squat' }));
  assertEquals(firstExercise(low).match?.confidence, 'low');
  assertEquals(low.flags.uncertainExercises, true);
});

Deno.test('a suggestion that is not in the catalog is not a match', () => {
  const r = ok(workout([{ sets: 1, reps: 1, percent: 90 }], { name: 'Zercher', match: 'Zercher Squat' }));
  assertEquals(firstExercise(r).match, null);
  assertEquals(r.flags.uncertainExercises, true);
});

Deno.test('resolves a basis lift by name and flags one it cannot find', () => {
  const r = ok(workout([{ sets: 1, reps: 1, percent: 75, basisExercise: 'clean & jerk' }]));
  assertEquals(firstSet(r).basisExercise, {
    name: 'clean & jerk',
    match: { exerciseId: 'cj', name: 'Clean & Jerk', confidence: 'exact' },
  });
  const unknown = ok(workout([{ sets: 1, reps: 1, percent: 75, basisExercise: 'best deadlift' }]));
  assertEquals(firstSet(unknown).basisExercise?.match, null);
  assertEquals(unknown.flags.uncertainExercises, true);
});

const trainingDay = (weekday: string) => ({
  weekday,
  exercises: [{ name: 'Back Squat', prescriptions: [{ sets: 1, reps: 1, percent: 90 }] }],
});

Deno.test('fills the rest days a weekday-named week leaves out', () => {
  const r = ok({
    type: 'program',
    weeks: [{ days: [trainingDay('Friday'), trainingDay('monday'), trainingDay('wed')] }],
  });
  assertEquals(r.weeks[0].days.map((d) => [d.weekday, d.isRestDay]), [
    ['monday', false],
    ['tuesday', true],
    ['wednesday', false],
    ['thursday', true],
    ['friday', false],
    ['saturday', true],
    ['sunday', true],
  ]);
});

Deno.test('keeps two sessions on one weekday', () => {
  const r = ok({ type: 'program', weeks: [{ days: [trainingDay('monday'), trainingDay('monday')] }] });
  assertEquals(r.weeks[0].days.length, 8);
  assertEquals(r.weeks[0].days.filter((d) => d.weekday === 'monday').length, 2);
});

Deno.test('adds no rest days when days are only numbered', () => {
  const day = { title: 'Day 1', exercises: trainingDay('monday').exercises };
  const r = ok({ type: 'program', weeks: [{ days: [day, day] }] });
  assertEquals(r.weeks[0].days.length, 2);
});

Deno.test('a rest day with exercises on it is not a rest day', () => {
  const r = ok({ type: 'program', weeks: [{ days: [{ ...trainingDay('monday'), isRestDay: true }] }] });
  assertEquals(r.weeks[0].days[0].isRestDay, false);
});

Deno.test('several training days labelled a workout are detected as a program', () => {
  const out = normalizeResult({
    type: 'workout',
    weeks: [{ days: [trainingDay('monday'), trainingDay('tuesday')] }],
  }, CATALOG);
  assertEquals(out.kind === 'ok' && out.detectedType, 'program');
});

Deno.test('a re-run as a workout merges every day into one', () => {
  const r = ok(
    { type: 'program', weeks: [{ days: [trainingDay('monday'), trainingDay('tuesday')] }] },
    'workout',
  );
  assertEquals(r.type, 'workout');
  assertEquals(r.weeks.length, 1);
  assertEquals(r.weeks[0].days.length, 1);
  assertEquals(r.weeks[0].days[0].exercises.length, 2);
});

Deno.test('a re-run as a program stays a program', () => {
  assertEquals(ok(workout([{ sets: 1, reps: 1, percent: 90 }]), 'program').type, 'program');
});

Deno.test('nothing to read is "no workout found"', () => {
  assertEquals(normalizeResult({ type: 'none', weeks: [] }, CATALOG).kind, 'no_workout_found');
  assertEquals(normalizeResult({}, CATALOG).kind, 'no_workout_found');
});

Deno.test('a file with only unstructured content is still a result', () => {
  const out = normalizeResult({ type: 'none', unstructured: [{ originalText: '10 min EMOM' }] }, CATALOG);
  assertEquals(out.kind, 'ok');
});

Deno.test('something other than an object is invalid', () => {
  assertEquals(normalizeResult(undefined, CATALOG).kind, 'invalid');
  assertEquals(normalizeResult([1, 2], CATALOG).kind, 'invalid');
});

Deno.test('parses JSON inside a Markdown fence or surrounding prose', () => {
  assertEquals(parseModelJson('```json\n{"a": 1}\n```'), { a: 1 });
  assertEquals(parseModelJson('Here it is: {"a": 1} Done.'), { a: 1 });
  assertEquals(parseModelJson('{"a": '), undefined);
  assertEquals(parseModelJson('no json'), undefined);
});
