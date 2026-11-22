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
  /** Other names an official exercise answers to. Custom ones have none. */
  aliases?: string[];
  is_predefined?: boolean;
  retired_at?: string | null;
  created_at?: string;
}

/**
 * The one rule for "the same exercise name": whitespace collapsed, trimmed,
 * lowercased. Must match the database's normalize_exercise_name() and the
 * app's normalizeExerciseName() (lib/core/utils/exercise_name.dart); the
 * tests run the same cases as exercise_catalog.test.sql.
 */
export function normalizeExerciseName(name: string): string {
  return name.replace(/\s+/g, ' ').trim().toLowerCase();
}

/** Lower sorts first: active official, retired official, then custom. */
function catalogRank(e: CatalogExercise): number {
  if (!e.is_predefined) return 2;
  return e.retired_at ? 1 : 0;
}

export interface ImportSet {
  sets: number;
  reps?: number;
  repsMax?: number;
  percent?: number;
  percentMax?: number;
  weight?: number;
  unit?: 'kg' | 'lb';
  /**
   * No load is prescribed: the lifter picks the weight on the day, as for
   * "3x8 light by feel" or bodyweight work. Explicit, so the accept step
   * never mistakes an absolute load that lost its weight for one of these.
   */
  openLoad?: true;
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

/** One of a day's sessions (AM, PM …), each its own workout once started. */
export interface ImportSession {
  title?: string;
  notes?: string;
  exercises: ImportExercise[];
}

/** A day holds 1 to MAX_SESSIONS_PER_DAY sessions, always at least one. */
export interface ImportDay {
  title?: string;
  weekday?: string;
  isRestDay: boolean;
  notes?: string;
  sessions: ImportSession[];
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
  /** 2: days hold `sessions`. 1 (stored before #175): days held `exercises`. */
  schemaVersion: 2;
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
    // Names and aliases, in the order the server's find_exercise_for_user()
    // and the app's findExerciseByName() pick: active official, retired
    // official, then the oldest custom row. First one wins.
    const ordered = [...exercises].sort((a, b) =>
      catalogRank(a) - catalogRank(b) || (a.created_at ?? '').localeCompare(b.created_at ?? '')
    );
    for (const e of ordered) {
      for (const name of [e.name, ...(e.aliases ?? [])]) {
        const key = normalizeExerciseName(name);
        if (key && !this.byName.has(key)) this.byName.set(key, e);
      }
    }
  }

  find(name: string | undefined) {
    return name === undefined ? undefined : this.byName.get(normalizeExerciseName(name));
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

  const percentValue = parseValue(raw.percent);
  const percentMaxValue = parseValue(raw.percentMax);
  const percent = inRange(percentValue.low, 0.5, 200) ? percentValue.low : undefined;
  const weightValue = parseValue(raw.weight).low;
  const weight = inRange(weightValue, 0.25, 2000) ? weightValue : undefined;
  if (percent === undefined && weight === undefined) {
    // A load that was printed but couldn't be read must not become "choose
    // load": the user would lose the prescription without noticing. A set
    // with no load at all is an open set, as long as it prescribes something
    // (reps, or wording such as "max reps" in its note).
    const unreadableLoad = unreadable.has('load') || isPresent(raw.percent) || isPresent(raw.weight);
    if (unreadableLoad || (!isPresent(raw.reps) && !keepNote)) {
      ctx.unstructured.push({
        location,
        originalText: `${describeSet(raw)}${unreadableLoad ? ' (load could not be read)' : ''}`,
      });
      return null;
    }
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
  } else if (weight !== undefined) {
    set.weight = weight;
    const unit = normalizeUnit(raw.unit);
    if (unit) set.unit = unit;
  } else {
    set.openLoad = true;
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

/**
 * The most sessions a program day holds. The database refuses a 4th
 * (enforce_program_day_session_limit); start_program makes each its own
 * workout on the day's date.
 */
export const MAX_SESSIONS_PER_DAY = 3;

function normalizeSession(raw: Raw, location: string, ctx: Context): ImportSession {
  const title = asText(raw.title);
  const notes = asText(raw.notes);
  const exercises = asArray(raw.exercises).flatMap((e) => {
    const obj = asObject(e);
    return (obj && normalizeExercise(obj, location, ctx)) ?? [];
  });
  return { ...(title ? { title } : {}), ...(notes ? { notes } : {}), exercises };
}

/**
 * At most MAX_SESSIONS_PER_DAY sessions: any beyond go into the last one, in
 * order, and an unstructured entry says so, so nothing is silently merged.
 */
function capSessions(sessions: ImportSession[], location: string, ctx: Context): ImportSession[] {
  if (sessions.length <= MAX_SESSIONS_PER_DAY) return sessions;
  const kept = sessions.slice(0, MAX_SESSIONS_PER_DAY - 1);
  const rest = sessions.slice(MAX_SESSIONS_PER_DAY - 1);
  const titles = rest.map((s, i) => s.title ?? `Session ${MAX_SESSIONS_PER_DAY + i}`);
  const notes = rest.flatMap((s) => s.notes ?? []).join('\n');
  ctx.unstructured.push({
    location,
    originalText: `${sessions.length} sessions on one day; a day holds ${MAX_SESSIONS_PER_DAY}, so ${
      titles.join(', ')
    } are combined into one.`,
  });
  return [...kept, {
    title: titles.join(' / '),
    ...(notes ? { notes } : {}),
    exercises: rest.flatMap((s) => s.exercises),
  }];
}

/** Every exercise of a day, session by session. */
export const dayExercises = (day: ImportDay) => day.sessions.flatMap((s) => s.exercises);

function normalizeDay(raw: Raw, location: string, ctx: Context): ImportDay {
  const title = asText(raw.title);
  const weekday = normalizeWeekday(raw.weekday);
  const notes = asText(raw.notes);
  const dayLocation = title ? `${location}, ${title}` : location;
  // A day of 2–3 sessions lists them in "sessions"; a day of one lists its
  // exercises directly, which keeps the common case short.
  const rawSessions = asArray(raw.sessions).flatMap((s): Raw[] => {
    const obj = asObject(s);
    return obj ? [obj] : [];
  });
  const sessions = rawSessions.length > 0
    ? capSessions(
      rawSessions.map((s, i) =>
        normalizeSession(
          s,
          rawSessions.length > 1 ? `${dayLocation}, ${asText(s.title) ?? `Session ${i + 1}`}` : dayLocation,
          ctx,
        )
      ),
      dayLocation,
      ctx,
    )
    : [normalizeSession({ exercises: raw.exercises }, dayLocation, ctx)];
  const day: ImportDay = {
    ...(title ? { title } : {}),
    ...(weekday ? { weekday } : {}),
    isRestDay: false,
    ...(notes ? { notes } : {}),
    sessions,
  };
  // A "rest day" with exercises on it is not a rest day.
  day.isRestDay = raw.isRestDay === true && dayExercises(day).length === 0;
  return day;
}

/**
 * The most days a program week holds. The database refuses an 8th
 * (enforce_program_week_day_limit), and start_program gives every week 7
 * calendar days: a day lands on start + 7 × week index + its place in the week.
 */
export const MAX_DAYS_PER_WEEK = 7;

const NUMBERED_DAY = /^day\s*\d+$/i;

/**
 * Splits a week of numbered days longer than a week ("Day 1" … "Day 20") into
 * weeks of seven, in order, before its days are read, so the locations in
 * flagged content name the week each day ends up in. A "Day N" title restarts
 * at Day 1 in each week. A weekday-named week is left whole: fillRestDays
 * makes it one calendar week.
 */
function splitRawWeek(raw: Raw): Raw[] {
  const days = asArray(raw.days);
  const weekdayNamed = days.length > 0 &&
    days.every((d) => normalizeWeekday(asObject(d)?.weekday) !== undefined);
  if (weekdayNamed || days.length <= MAX_DAYS_PER_WEEK) return [raw];
  const weeks: Raw[] = [];
  for (let start = 0; start < days.length; start += MAX_DAYS_PER_WEEK) {
    weeks.push({
      // The label names the program's week, so only its first part keeps it.
      ...(start === 0 && raw.label !== undefined ? { label: raw.label } : {}),
      days: days.slice(start, start + MAX_DAYS_PER_WEEK).map((d, i) => {
        const obj = asObject(d);
        const title = obj && asText(obj.title);
        return obj && title && NUMBERED_DAY.test(title) ? { ...obj, title: `Day ${i + 1}` } : d;
      }),
    });
  }
  return weeks;
}

/** Backstop for a week still over 7 days after normalizing: weeks of seven. */
function splitWeek(week: ImportWeek): ImportWeek[] {
  if (week.days.length <= MAX_DAYS_PER_WEEK) return [week];
  const weeks: ImportWeek[] = [];
  for (let start = 0; start < week.days.length; start += MAX_DAYS_PER_WEEK) {
    weeks.push({
      ...(start === 0 && week.label ? { label: week.label } : {}),
      days: week.days.slice(start, start + MAX_DAYS_PER_WEEK),
    });
  }
  return weeks;
}

/**
 * Several entries for one weekday (AM and PM listed as separate days) as one
 * day, since a week holds one day per weekday: each entry's sessions become
 * that day's sessions, in order, titled by the entry when it has a title and
 * the session has none. Over MAX_SESSIONS_PER_DAY, capSessions combines the
 * rest.
 */
function mergeSessions(entries: ImportDay[], location: string, ctx: Context): ImportDay {
  if (entries.length === 1) return entries[0];
  const sessions = entries.flatMap((d) =>
    d.sessions.map((s) => {
      const title = s.title ?? (d.sessions.length === 1 ? d.title : undefined);
      // A day's notes describe its one session when it's an entry of its own.
      const notes = [d.sessions.length === 1 ? d.notes : undefined, s.notes].filter(Boolean).join('\n');
      return { ...(title ? { title } : {}), ...(notes ? { notes } : {}), exercises: s.exercises };
    })
  );
  const merged: ImportDay = {
    weekday: entries[0].weekday,
    isRestDay: false,
    sessions: capSessions(sessions, location, ctx),
  };
  merged.isRestDay = dayExercises(merged).length === 0 && entries.every((d) => d.isRestDay);
  return merged;
}

/**
 * Makes a weekday-named week its seven days, Monday to Sunday: inserts the
 * rest days it leaves out, so the sessions keep their weekdays, and makes
 * several entries on one weekday that day's sessions. Only applies when every
 * day names its weekday.
 */
function fillRestDays(week: ImportWeek, weekLocation: string, ctx: Context): ImportWeek {
  if (week.days.length === 0 || week.days.some((d) => !d.weekday)) return week;
  const days = WEEKDAYS.map((weekday): ImportDay => {
    const onDay = week.days.filter((d) => d.weekday === weekday);
    return onDay.length
      ? mergeSessions(onDay, `${weekLocation}, ${weekday[0].toUpperCase()}${weekday.slice(1)}`, ctx)
      : { weekday, isRestDay: true, sessions: [{ exercises: [] }] };
  });
  return { ...week, days };
}

const hasContent = (day: ImportDay) => dayExercises(day).length > 0;

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
  const rawWeeks = asObjects(raw.weeks).flatMap(splitRawWeek);
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

  const fromModel = [
    ...asArray(raw.unstructured).flatMap((u) => {
      const obj = asObject(u);
      const originalText = asText(obj ? obj.originalText : u);
      if (!originalText) return [];
      const location = obj ? asText(obj.location) : undefined;
      return [{ ...(location ? { location } : {}), originalText }];
    }),
  ];

  const trainingDays = weeks.flatMap((w) => w.days).filter(hasContent);
  if (trainingDays.length === 0 && fromModel.length === 0 && ctx.unstructured.length === 0) {
    return { kind: 'no_workout_found' };
  }

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
      sessions: [{ exercises: trainingDays.flatMap(dayExercises) }],
    };
    const notes = trainingDays.flatMap((d) => d.notes ?? []).join('\n');
    if (notes) merged.notes = notes;
    weeks = [{ days: [merged] }];
  } else {
    weeks = weeks
      .map((w, i) => fillRestDays(w, w.label ?? (isProgramShaped ? `Week ${i + 1}` : 'Workout'), ctx))
      .flatMap(splitWeek);
  }

  // Read after fillRestDays, which can add to ctx.unstructured.
  const unstructured = [...fromModel, ...ctx.unstructured];
  const allExercises = weeks.flatMap((w) => w.days).flatMap(dayExercises);
  const allSets = allExercises.flatMap((e) => e.sets);
  const title = asText(raw.title);
  return {
    kind: 'ok',
    detectedType,
    result: {
      schemaVersion: 2,
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
