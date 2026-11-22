import { assertEquals } from 'jsr:@std/assert@1';
import {
  type CatalogExercise,
  dayExercises,
  type ImportResult,
  normalizeExerciseName,
  normalizeResult,
  parseModelJson,
} from './normalize.ts';

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

const firstExercise = (r: ImportResult) => dayExercises(r.weeks[0].days[0])[0];
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

Deno.test("two entries on one weekday become that day's two sessions", () => {
  const am = { ...trainingDay('monday'), title: 'AM', notes: 'Snatch focus' };
  const pm = {
    weekday: 'monday',
    title: 'PM',
    exercises: [{ name: 'Front Squat', prescriptions: [{ sets: 1, reps: 3, percent: 80 }] }],
  };
  const r = ok({ type: 'program', weeks: [{ days: [am, pm] }] });
  assertEquals(r.weeks[0].days.length, 7);
  const monday = r.weeks[0].days[0];
  assertEquals(monday.title, undefined);
  assertEquals(monday.sessions.map((s) => [s.title, s.notes, s.exercises.map((e) => e.name)]), [
    ['AM', 'Snatch focus', ['Back Squat']],
    ['PM', undefined, ['Front Squat']],
  ]);
  assertEquals(r.unstructured, []);
});

Deno.test("a day's sessions are kept apart, in order", () => {
  const r = ok({
    type: 'program',
    weeks: [{
      days: [{
        weekday: 'monday',
        notes: 'Two-a-day',
        sessions: [
          { title: 'AM', exercises: trainingDay('monday').exercises },
          { exercises: [{ name: 'Front Squat', prescriptions: [{ reps: 3, percent: 80 }] }] },
        ],
      }],
    }],
  });
  const monday = r.weeks[0].days[0];
  assertEquals(monday.notes, 'Two-a-day');
  assertEquals(monday.isRestDay, false);
  assertEquals(monday.sessions.map((s) => s.title), ['AM', undefined]);
  assertEquals(dayExercises(monday).map((e) => e.name), ['Back Squat', 'Front Squat']);
});

Deno.test('a day with one session lists it as one', () => {
  const r = ok({ type: 'program', weeks: [{ days: [trainingDay('monday')] }] });
  assertEquals(r.schemaVersion, 2);
  assertEquals(r.weeks[0].days[0].sessions.length, 1);
  // A rest day the week leaves out gets one empty session too.
  assertEquals(r.weeks[0].days[1].sessions, [{ exercises: [] }]);
});

Deno.test('a 4th session is combined into the 3rd, and says so', () => {
  const session = (title: string) => ({ title, exercises: trainingDay('monday').exercises });
  const r = ok({
    type: 'program',
    weeks: [{ days: [{ weekday: 'monday', sessions: ['A', 'B', 'C', 'D'].map(session) }] }],
  });
  const monday = r.weeks[0].days[0];
  assertEquals(monday.sessions.map((s) => [s.title, s.exercises.length]), [['A', 1], ['B', 1], ['C / D', 2]]);
  assertEquals(r.unstructured.length, 1);
  assertEquals(r.unstructured[0].location, 'Workout, Monday');
  assertEquals(r.flags.unstructuredContent, true);
});

Deno.test('four entries on one weekday fold into 3 sessions', () => {
  const entry = (title: string) => ({ ...trainingDay('tuesday'), title });
  const r = ok({ type: 'program', weeks: [{ days: ['1', '2', '3', '4'].map(entry) }] });
  const tuesday = r.weeks[0].days[1];
  assertEquals(tuesday.sessions.map((s) => s.title), ['1', '2', '3 / 4']);
  assertEquals(r.unstructured.map((u) => u.location), ['Workout, Tuesday']);
});

Deno.test('a re-run as a workout puts every session in one', () => {
  const r = ok({
    type: 'program',
    weeks: [{
      days: [{
        weekday: 'monday',
        sessions: [
          { title: 'AM', exercises: trainingDay('monday').exercises },
          { title: 'PM', exercises: trainingDay('monday').exercises },
        ],
      }, trainingDay('tuesday')],
    }],
  }, 'workout');
  assertEquals(r.weeks[0].days.length, 1);
  assertEquals(r.weeks[0].days[0].sessions.length, 1);
  assertEquals(r.weeks[0].days[0].sessions[0].exercises.length, 3);
});

Deno.test('splits numbered days into weeks of seven, restarting the titles', () => {
  const days = Array.from(
    { length: 20 },
    (_, i) =>
      i === 6 || i === 13 ? { title: `Day ${i + 1}`, isRestDay: true } : {
        title: `Day ${i + 1}`,
        exercises: trainingDay('monday').exercises,
      },
  );
  const r = ok({ type: 'program', weeks: [{ label: 'Arm challenge', days }] });
  assertEquals(r.weeks.map((w) => w.days.length), [7, 7, 6]);
  assertEquals(r.weeks.map((w) => w.label), ['Arm challenge', undefined, undefined]);
  assertEquals(r.weeks[1].days.map((d) => d.title), [
    'Day 1',
    'Day 2',
    'Day 3',
    'Day 4',
    'Day 5',
    'Day 6',
    'Day 7',
  ]);
  assertEquals(r.weeks[1].days[6].isRestDay, true);
});

Deno.test('keeps a day title that is not a day number when splitting', () => {
  const days = Array.from({ length: 8 }, (_, i) => ({
    title: i === 7 ? 'Test day' : `Day ${i + 1}`,
    exercises: trainingDay('monday').exercises,
  }));
  const r = ok({ type: 'program', weeks: [{ days }] });
  assertEquals(r.weeks[1].days.map((d) => d.title), ['Test day']);
});

Deno.test('names the split week in flagged content', () => {
  const days = Array.from({ length: 9 }, (_, i) => ({
    title: `Day ${i + 1}`,
    exercises: [{
      name: 'Back Squat',
      prescriptions: i === 8 ? [{ sets: 3, reps: 5, weight: 'smudged' }] : [{ reps: 3, percent: 70 }],
    }],
  }));
  const r = ok({ type: 'program', weeks: [{ days }] });
  assertEquals(r.weeks.length, 2);
  assertEquals(r.unstructured.some((u) => u.location?.startsWith('Week 2, Day 2')), true);
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
  assertEquals(dayExercises(r.weeks[0].days[0]).length, 2);
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

// The same cases as exercise_catalog.test.sql and exercise_name_test.dart.
Deno.test('normalizeExerciseName matches the database and app rules', () => {
  assertEquals(normalizeExerciseName('  Clean   &  Jerk '), 'clean & jerk');
  assertEquals(normalizeExerciseName('BACK\tSquat\n'), 'back squat');
  assertEquals(normalizeExerciseName('Pull-Up'), 'pull-up');
  assertEquals(normalizeExerciseName('   '), '');
});

Deno.test('an official exercise is found by its alias, as written or as a suggestion', () => {
  const catalog = [{ id: 'cj', name: 'Clean & Jerk', aliases: ['C&J'], is_predefined: true }];
  const named = normalizeResult(workout([{ sets: 1, reps: 1, percent: 90 }], { name: 'c&j' }), catalog);
  if (named.kind !== 'ok') throw new Error(named.kind);
  assertEquals(firstExercise(named.result).match, {
    exerciseId: 'cj',
    name: 'Clean & Jerk',
    confidence: 'exact',
  });

  const suggested = normalizeResult(
    workout([{ sets: 1, reps: 1, percent: 90 }], { name: 'CJ', match: 'C&J', confidence: 'high' }),
    catalog,
  );
  if (suggested.kind !== 'ok') throw new Error(suggested.kind);
  assertEquals(firstExercise(suggested.result).match?.exerciseId, 'cj');
});

Deno.test('one name: active official, then retired official, then the oldest custom', () => {
  const custom = { id: 'mine', name: 'C&J', is_predefined: false, created_at: '2024-01-01' };
  const retired = {
    id: 'old',
    name: 'C&J Old',
    aliases: ['C&J'],
    is_predefined: true,
    retired_at: '2026-01-01',
  };
  const active = { id: 'cj', name: 'Clean & Jerk', aliases: ['C&J'], is_predefined: true };
  const newerCustom = { id: 'mine2', name: 'c&j', is_predefined: false, created_at: '2025-01-01' };
  const pick = (catalog: CatalogExercise[]) => {
    const out = normalizeResult(workout([{ sets: 1, reps: 1, percent: 90 }], { name: 'C&J' }), catalog);
    if (out.kind !== 'ok') throw new Error(out.kind);
    return firstExercise(out.result).match?.exerciseId;
  };
  assertEquals(pick([custom, retired, active]), 'cj');
  assertEquals(pick([custom, retired]), 'old');
  assertEquals(pick([newerCustom, custom]), 'mine');
});
