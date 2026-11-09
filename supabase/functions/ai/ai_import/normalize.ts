import type { ImportType } from './prompt.ts';

/**
 * Turns whatever the model returned into a result that satisfies the set
 * constraints in the database. The model doesn't reliably follow a schema, and
 * one bad field shouldn't cost a user their whole import, so a bad value is
 * moved somewhere visible (a note or `unstructured`) and never silently dropped.
 */

export type MatchConfidence = 'exact' | 'high' | 'low';

export interface ExerciseMatch {
  exerciseId: string;
  name: string;
  confidence: MatchConfidence;
}

export interface CatalogExercise {
  id: string;
  name: string;
}

export interface ImportSet {
  sets: number;
  reps?: number;
  repsMax?: number;
  percent?: number;
  percentMax?: number;
  weight?: number;
  unit?: 'kg' | 'lb';
  rpeMin?: number;
  rpeMax?: number;
  basisExercise?: { name: string; match: ExerciseMatch | null };
  note?: string;
  unreadable?: string[];
}

export interface ImportExercise {
  name: string;
  match: ExerciseMatch | null;
  notes?: string;
  sets: ImportSet[];
}

export interface ImportDay {
  title?: string;
  weekday?: string;
  isRestDay: boolean;
  notes?: string;
  exercises: ImportExercise[];
}

export interface ImportWeek {
  label?: string;
  days: ImportDay[];
}

export interface UnstructuredItem {
  location?: string;
  originalText: string;
}

export interface ImportResult {
  schemaVersion: 1;
  type: ImportType;
  title?: string;
  weeks: ImportWeek[];
  unstructured: UnstructuredItem[];
  flags: {
    /** Written by hand, so the review tells the user to check every weight. */
    handwritten: boolean;
    /** An absolute weight has no printed unit, so Accept needs a kg/lb choice. */
    needsUnit: boolean;
    uncertainExercises: boolean;
    unreadableValues: boolean;
    unstructuredContent: boolean;
  };
}

export type NormalizeOutcome =
  | { kind: 'ok'; result: ImportResult; detectedType: ImportType }
  | { kind: 'no_workout_found' }
  | { kind: 'invalid' };

type Raw = Record<string, unknown>;

const WEEKDAYS = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
const MAX_TEXT = 2000;
const NUMBER = String.raw`\d+(?:\.\d+)?`;
const SINGLE = new RegExp(`^(${NUMBER})\\s*%?$`);
const RANGE = new RegExp(`^(${NUMBER})\\s*%?\\s*(?:-|–|—|to)\\s*(${NUMBER})\\s*%?$`, 'i');

const asObject = (v: unknown): Raw | undefined =>
  v && typeof v === 'object' && !Array.isArray(v) ? v as Raw : undefined;
const asArray = (v: unknown): unknown[] => Array.isArray(v) ? v : [];
const asObjects = (v: unknown): Raw[] => asArray(v).filter((x): x is Raw => asObject(x) !== undefined);

function asText(v: unknown): string | undefined {
  if (typeof v === 'number') return String(v);
  if (typeof v !== 'string') return undefined;
  const t = v.trim();
  return t ? t.slice(0, MAX_TEXT) : undefined;
}

const isPresent = (v: unknown) => v !== undefined && v !== null && v !== '';

/** A number, or a range written in one field such as "5-8" or "67-72.5%". */
function parseValue(v: unknown): { low?: number; high?: number } {
  if (typeof v === 'number') return Number.isFinite(v) ? { low: v } : {};
  if (typeof v !== 'string') return {};
  const t = v.trim();
  const range = t.match(RANGE);
  if (range) return { low: Number(range[1]), high: Number(range[2]) };
  const single = t.match(SINGLE);
  return single ? { low: Number(single[1]) } : {};
}

function normalizeUnit(v: unknown): 'kg' | 'lb' | undefined {
  const t = asText(v)?.toLowerCase().replace(/\.$/, '');
  if (t === undefined) return undefined;
  if (['kg', 'kgs', 'kilo', 'kilos', 'kilogram', 'kilograms'].includes(t)) return 'kg';
  if (['lb', 'lbs', 'pound', 'pounds', '#'].includes(t)) return 'lb';
  return undefined;
}

function normalizeWeekday(v: unknown): string | undefined {
  const t = asText(v)?.toLowerCase();
  return t && t.length >= 3 ? WEEKDAYS.find((d) => d.startsWith(t.slice(0, 3))) : undefined;
}

class Catalog {
  private byName = new Map<string, CatalogExercise>();

  constructor(exercises: CatalogExercise[]) {
    // First one wins, the same as ensureExerciseByName with duplicate names.
    for (const e of exercises) {
      const key = Catalog.key(e.name);
      if (!this.byName.has(key)) this.byName.set(key, e);
    }
  }

  // The same rule as ensureExerciseByName: trimmed and case-insensitive.
  private static key(name: string) {
    return name.trim().toLowerCase();
  }

  find(name: string | undefined) {
    return name === undefined ? undefined : this.byName.get(Catalog.key(name));
  }

  /** A name in the catalog beats the model's suggestion. A suggestion must exist. */
  match(name: string, suggested: unknown, confidence: unknown): ExerciseMatch | null {
    const exact = this.find(name);
    if (exact) return { exerciseId: exact.id, name: exact.name, confidence: 'exact' };
    const found = this.find(asText(suggested));
    if (!found) return null;
    return { exerciseId: found.id, name: found.name, confidence: confidence === 'high' ? 'high' : 'low' };
  }
}

function describeSet(raw: Raw): string {
  const reps = isPresent(raw.repsMax) ? `${raw.reps}-${raw.repsMax}` : raw.reps;
  const parts: string[] = [];
  if (isPresent(raw.sets) && isPresent(raw.reps)) parts.push(`${raw.sets} x ${reps}`);
  else if (isPresent(raw.reps)) parts.push(`${reps} reps`);
  else if (isPresent(raw.sets)) parts.push(`${raw.sets} sets`);
  if (isPresent(raw.percent)) {
    parts.push(isPresent(raw.percentMax) ? `${raw.percent}-${raw.percentMax}%` : `${raw.percent}%`);
  }
  if (isPresent(raw.weight)) parts.push(`${raw.weight}${asText(raw.unit) ?? ''}`);
  if (isPresent(raw.rpeMin)) {
    parts.push(isPresent(raw.rpeMax) ? `RPE ${raw.rpeMin}-${raw.rpeMax}` : `RPE ${raw.rpeMin}`);
  }
  const note = asText(raw.note);
  if (note) parts.push(note);
  return parts.join(' ') || 'A set with no details';
}

interface Context {
  catalog: Catalog;
  unstructured: UnstructuredItem[];
}

function normalizeSet(raw: Raw, location: string, ctx: Context): ImportSet | null {
  const unreadable = new Set(asArray(raw.unreadable).flatMap((v) => asText(v) ?? []));
  const notes: string[] = [];
  const keepNote = asText(raw.note);
  if (keepNote) notes.push(keepNote);
  const asPrinted = (label: string, value: unknown, field: string) => {
    notes.push(`${label} as printed: ${asText(value) ?? JSON.stringify(value)}`);
    unreadable.add(field);
  };

  const inRange = (n: number | undefined, min: number, max: number) =>
    n !== undefined && n >= min && n <= max;

  // Load decides whether this can be a set at all: the database has no shape
  // for a set without one until #66 ships.
  const percentValue = parseValue(raw.percent);
  const percentMaxValue = parseValue(raw.percentMax);
  const percent = inRange(percentValue.low, 0.5, 200) ? percentValue.low : undefined;
  const weightValue = parseValue(raw.weight).low;
  const weight = inRange(weightValue, 0.25, 2000) ? weightValue : undefined;
  if (percent === undefined && weight === undefined) {
    const unreadableLoad = unreadable.has('load') || isPresent(raw.percent) || isPresent(raw.weight);
    ctx.unstructured.push({
      location,
      originalText: `${describeSet(raw)}${unreadableLoad ? ' (load could not be read)' : ''}`,
    });
    return null;
  }

  const set: ImportSet = { sets: 1 };

  const setsValue = parseValue(raw.sets).low;
  if (setsValue !== undefined && Number.isInteger(setsValue) && inRange(setsValue, 1, 50)) {
    set.sets = setsValue;
  } else if (isPresent(raw.sets)) {
    asPrinted('Sets', raw.sets, 'sets');
  }

  const repsValue = parseValue(raw.reps);
  const repsMaxRaw = repsValue.high ?? parseValue(raw.repsMax).low;
  const validReps = (n: number | undefined) => n !== undefined && Number.isInteger(n) && inRange(n, 1, 1000);
  if (validReps(repsValue.low)) {
    set.reps = repsValue.low;
    if (validReps(repsMaxRaw) && repsMaxRaw! >= repsValue.low!) {
      if (repsMaxRaw! > repsValue.low!) set.repsMax = repsMaxRaw;
    } else if (isPresent(raw.repsMax)) {
      asPrinted('Rep range top', raw.repsMax, 'reps');
    }
  } else if (isPresent(raw.reps)) {
    asPrinted('Reps', raw.reps, 'reps');
  }

  if (percent !== undefined) {
    set.percent = percent;
    const top = percentValue.high ?? percentMaxValue.low;
    if (inRange(top, percent, 200)) {
      if (top! > percent) set.percentMax = top;
    } else if (isPresent(raw.percentMax) || percentValue.high !== undefined) {
      asPrinted('Percentage range top', raw.percentMax ?? raw.percent, 'load');
    }
    // A percentage scales to the lifter, so it wins, but the printed load stays visible.
    if (weight !== undefined) notes.push(`Printed load: ${weight}${normalizeUnit(raw.unit) ?? ''}`);
  } else {
    set.weight = weight;
    const unit = normalizeUnit(raw.unit);
    if (unit) set.unit = unit;
  }

  const validRpe = (n: number | undefined) => inRange(n, 1, 10) && Number.isInteger(n! * 2);
  const rpeValue = parseValue(raw.rpeMin ?? raw.rpe);
  const rpeTop = rpeValue.high ?? parseValue(raw.rpeMax).low;
  if (validRpe(rpeValue.low)) {
    set.rpeMin = rpeValue.low;
    if (validRpe(rpeTop) && rpeTop! >= rpeValue.low!) {
      if (rpeTop! > rpeValue.low!) set.rpeMax = rpeTop;
    } else if (isPresent(raw.rpeMax)) {
      asPrinted('RPE range top', raw.rpeMax, 'rpe');
    }
  } else if (isPresent(raw.rpeMin ?? raw.rpe)) {
    asPrinted('RPE', raw.rpeMin ?? raw.rpe, 'rpe');
  }

  const basis = asText(raw.basisExercise);
  if (basis && set.percent !== undefined) {
    set.basisExercise = { name: basis, match: ctx.catalog.match(basis, undefined, undefined) };
  }

  if (notes.length) set.note = notes.join('. ').slice(0, MAX_TEXT);
  if (unreadable.size) set.unreadable = [...unreadable];
  return set;
}

function normalizeExercise(raw: Raw, dayLocation: string, ctx: Context): ImportExercise | null {
  const name = asText(raw.name);
  if (!name) {
    const prescriptions = asObjects(raw.prescriptions);
    if (prescriptions.length) {
      ctx.unstructured.push({
        location: dayLocation,
        originalText: `Unnamed exercise: ${prescriptions.map(describeSet).join('; ')}`,
      });
    }
    return null;
  }

  const location = `${dayLocation}, ${name}`;
  const sets = asArray(raw.prescriptions).flatMap((p) => {
    const obj = asObject(p);
    return (obj && normalizeSet(obj, location, ctx)) ?? [];
  });
  const notes = asText(raw.notes);
  return {
    name,
    match: ctx.catalog.match(name, raw.match, raw.confidence),
    ...(notes ? { notes } : {}),
    sets,
  };
}

function normalizeDay(raw: Raw, location: string, ctx: Context): ImportDay {
  const title = asText(raw.title);
  const weekday = normalizeWeekday(raw.weekday);
  const notes = asText(raw.notes);
  const dayLocation = title ? `${location}, ${title}` : location;
  const exercises = asArray(raw.exercises).flatMap((e) => {
    const obj = asObject(e);
    return (obj && normalizeExercise(obj, dayLocation, ctx)) ?? [];
  });
  return {
    ...(title ? { title } : {}),
    ...(weekday ? { weekday } : {}),
    // A "rest day" with exercises on it is not a rest day.
    isRestDay: raw.isRestDay === true && exercises.length === 0,
    ...(notes ? { notes } : {}),
    exercises,
  };
}

/**
 * Inserts the rest days a weekday-named week leaves out. start_program dates
 * each day as start + position, so a missing rest day would schedule the
 * sessions on consecutive days. Only applies when every day names its weekday.
 */
function fillRestDays(week: ImportWeek): ImportWeek {
  if (week.days.length === 0 || week.days.some((d) => !d.weekday)) return week;
  const days = WEEKDAYS.flatMap((weekday) => {
    const onDay = week.days.filter((d) => d.weekday === weekday);
    return onDay.length ? onDay : [{ weekday, isRestDay: true, exercises: [] }];
  });
  return { ...week, days };
}

const hasContent = (day: ImportDay) => day.exercises.length > 0;

/** Parses the model's text, tolerating Markdown fences and surrounding prose. */
export function parseModelJson(text: string): unknown {
  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  if (start < 0 || end <= start) return undefined;
  try {
    return JSON.parse(text.slice(start, end + 1));
  } catch {
    return undefined;
  }
}

export function normalizeResult(
  rawResult: unknown,
  catalogExercises: CatalogExercise[],
  requestedType?: ImportType,
): NormalizeOutcome {
  const raw = asObject(rawResult);
  if (!raw) return { kind: 'invalid' };

  const ctx: Context = { catalog: new Catalog(catalogExercises), unstructured: [] };
  const rawWeeks = asObjects(raw.weeks);
  const isProgramShaped = rawWeeks.length > 1;

  let weeks: ImportWeek[] = rawWeeks.map((w, weekIndex) => {
    const label = asText(w.label);
    const weekLocation = label ?? (isProgramShaped ? `Week ${weekIndex + 1}` : 'Workout');
    const days = asArray(w.days).flatMap((d, dayIndex) => {
      const obj = asObject(d);
      if (!obj) return [];
      const weekday = normalizeWeekday(obj.weekday);
      const where = weekday
        ? `${weekLocation}, ${weekday[0].toUpperCase()}${weekday.slice(1)}`
        : `${weekLocation}, Day ${dayIndex + 1}`;
      return [normalizeDay(obj, where, ctx)];
    });
    return { ...(label ? { label } : {}), days };
  });

  const unstructured = [
    ...asArray(raw.unstructured).flatMap((u) => {
      const obj = asObject(u);
      const originalText = asText(obj ? obj.originalText : u);
      if (!originalText) return [];
      const location = obj ? asText(obj.location) : undefined;
      return [{ ...(location ? { location } : {}), originalText }];
    }),
    ...ctx.unstructured,
  ];

  const trainingDays = weeks.flatMap((w) => w.days).filter(hasContent);
  if (trainingDays.length === 0 && unstructured.length === 0) return { kind: 'no_workout_found' };

  const detectedType: ImportType = raw.type === 'workout' && trainingDays.length <= 1
    ? 'workout'
    : raw.type === 'program'
    ? 'program'
    : trainingDays.length > 1
    ? 'program'
    : 'workout';
  const type = requestedType ?? detectedType;

  if (type === 'workout') {
    // Backstop for a re-run as a workout: one day holding everything, in order.
    const only = trainingDays[0];
    const merged: ImportDay = {
      ...(trainingDays.length === 1 && only.title ? { title: only.title } : {}),
      isRestDay: false,
      exercises: trainingDays.flatMap((d) => d.exercises),
    };
    const notes = trainingDays.flatMap((d) => d.notes ?? []).join('\n');
    if (notes) merged.notes = notes;
    weeks = [{ days: [merged] }];
  } else {
    weeks = weeks.map(fillRestDays);
  }

  const allExercises = weeks.flatMap((w) => w.days).flatMap((d) => d.exercises);
  const allSets = allExercises.flatMap((e) => e.sets);
  const title = asText(raw.title);
  return {
    kind: 'ok',
    detectedType,
    result: {
      schemaVersion: 1,
      type,
      ...(title ? { title: title.slice(0, 200) } : {}),
      weeks,
      unstructured,
      flags: {
        handwritten: raw.handwritten === true,
        needsUnit: allSets.some((s) => s.weight !== undefined && !s.unit),
        uncertainExercises: allExercises.some((e) => e.match === null || e.match.confidence === 'low') ||
          allSets.some((s) => s.basisExercise && s.basisExercise.match === null),
        unreadableValues: allSets.some((s) => s.unreadable?.length),
        unstructuredContent: unstructured.length > 0,
      },
    },
  };
}
