import 'dart:convert';

import 'catalog.dart';
import 'prompt.dart';

/// Turns whatever the model returned into a result that satisfies the set
/// constraints in the database. Ported from
/// `supabase/functions/ai/ai_import/normalize.ts`, which it must keep matching
/// while the hosted path exists: the output is the JSON stored in
/// `ai_import_results.payload`, which the app's review (`AiImportResult`) and
/// `ai_import_accept` read.
///
/// Models don't reliably follow a schema, and one bad field shouldn't cost a
/// user their whole import, so a bad value is moved somewhere visible (a note
/// or `unstructured`) and never silently dropped.
///
/// Works on JSON maps rather than classes so the output is exactly the stored
/// format. The import schema, version 2:
///
/// ```text
/// { schemaVersion: 2, type, title?, description?, descriptionGenerated?,
///   weeks: [{ label?, days: [{ title?, weekday?, isRestDay, notes?,
///     sessions: [{ title?, notes?, exercises: [{ name, match, notes?,
///       sets: [{ sets, reps?, repsMax?, percent?, percentMax?, weight?, unit?,
///         openLoad?, rpeMin?, rpeMax?, basisExercise?, note?, unreadable? }] }] }] }] }],
///   unstructured: [{ location?, originalText }],
///   flags: { handwritten, needsUnit, uncertainExercises, unreadableValues, unstructuredContent } }
/// ```
typedef Json = Map<String, Object?>;

/// The outcome of [normalizeImportResult].
sealed class NormalizeOutcome {
  const NormalizeOutcome();
}

/// A result to review. [result] is the payload to store.
class NormalizeOk extends NormalizeOutcome {
  const NormalizeOk(this.result, this.detectedType);

  final Json result;
  final ImportType detectedType;
}

/// The file has no training content.
class NormalizeNoWorkout extends NormalizeOutcome {
  const NormalizeNoWorkout();
}

/// The model's reply isn't a JSON object.
class NormalizeInvalid extends NormalizeOutcome {
  const NormalizeInvalid();
}

/// The most sessions a program day holds. The database refuses a 4th
/// (`enforce_program_day_session_limit`).
const kMaxSessionsPerDay = 3;

/// The most days a program week holds. The database refuses an 8th
/// (`enforce_program_week_day_limit`).
const kMaxDaysPerWeek = 7;

const _weekdays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
const _maxText = 2000;
const _number = r'\d+(?:\.\d+)?';
final _single = RegExp('^($_number)\\s*%?\$');
final _range = RegExp('^($_number)\\s*%?\\s*(?:-|–|—|to)\\s*($_number)\\s*%?\$', caseSensitive: false);
final _numberedDay = RegExp(r'^day\s*\d+$', caseSensitive: false);

// ---------------------------------------------------------------------------
// Loose JSON helpers, matching the TypeScript's handling of `unknown`.
// ---------------------------------------------------------------------------

Json? _asObject(Object? v) => v is Map ? v.cast<String, Object?>() : null;
List<Object?> _asArray(Object? v) => v is List ? v.cast<Object?>() : const [];
List<Json> _asObjects(Object? v) => [for (final x in _asArray(v)) ?_asObject(x)];

/// An integral double as an int, so `70.0` is stored as `70`, as in JSON
/// from JavaScript.
num _clean(num n) => n is double && n.isFinite && n == n.truncateToDouble() ? n.toInt() : n;

/// JavaScript's `String(v)`, for text built from the model's raw values.
String _jsString(Object? v) => switch (v) {
  null => 'undefined',
  final num n => '${_clean(n)}',
  final String s => s,
  final List<Object?> l => l.map((x) => x == null ? '' : _jsString(x)).join(','),
  Map() => '[object Object]',
  _ => '$v',
};

String _truncate(String s, int max) => s.length > max ? s.substring(0, max) : s;

String? _asText(Object? v) {
  if (v is num) return _jsString(v);
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : _truncate(t, _maxText);
}

bool _isPresent(Object? v) => v != null && v != '';

bool _isInt(num n) => n.isFinite && n == n.truncateToDouble();

bool _inRange(num? n, num min, num max) => n != null && n >= min && n <= max;

/// A number, or a range written in one field such as "5-8" or "67-72.5%".
({num? low, num? high}) _parseValue(Object? v) {
  if (v is num) return v.isFinite ? (low: _clean(v), high: null) : (low: null, high: null);
  if (v is! String) return (low: null, high: null);
  final t = v.trim();
  final range = _range.firstMatch(t);
  if (range != null) return (low: _clean(num.parse(range[1]!)), high: _clean(num.parse(range[2]!)));
  final single = _single.firstMatch(t);
  return single != null ? (low: _clean(num.parse(single[1]!)), high: null) : (low: null, high: null);
}

String? _normalizeUnit(Object? v) {
  final t = _asText(v)?.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
  if (t == null) return null;
  if (const ['kg', 'kgs', 'kilo', 'kilos', 'kilogram', 'kilograms'].contains(t)) return 'kg';
  if (const ['lb', 'lbs', 'pound', 'pounds', '#'].contains(t)) return 'lb';
  return null;
}

String? _normalizeWeekday(Object? v) {
  final t = _asText(v)?.toLowerCase();
  if (t == null || t.length < 3) return null;
  final prefix = t.substring(0, 3);
  for (final d in _weekdays) {
    if (d.startsWith(prefix)) return d;
  }
  return null;
}

String _capitalized(String s) => '${s[0].toUpperCase()}${s.substring(1)}';

// ---------------------------------------------------------------------------
// Normalizing
// ---------------------------------------------------------------------------

class _Context {
  _Context(this.catalog);

  final ExerciseCatalog catalog;
  final unstructured = <Json>[];

  /// A name in the catalog beats the model's suggestion. A suggestion must exist.
  Json? match(String name, Object? suggested, Object? confidence) {
    final exact = catalog.find(name);
    if (exact != null) return {'exerciseId': exact.id, 'name': exact.name, 'confidence': 'exact'};
    final found = catalog.find(_asText(suggested));
    if (found == null) return null;
    return {'exerciseId': found.id, 'name': found.name, 'confidence': confidence == 'high' ? 'high' : 'low'};
  }
}

String _describeSet(Json raw) {
  final reps = _isPresent(raw['repsMax'])
      ? '${_jsString(raw['reps'])}-${_jsString(raw['repsMax'])}'
      : _jsString(raw['reps']);
  final parts = <String>[];
  if (_isPresent(raw['sets']) && _isPresent(raw['reps'])) {
    parts.add('${_jsString(raw['sets'])} x $reps');
  } else if (_isPresent(raw['reps'])) {
    parts.add('$reps reps');
  } else if (_isPresent(raw['sets'])) {
    parts.add('${_jsString(raw['sets'])} sets');
  }
  if (_isPresent(raw['percent'])) {
    parts.add(
      _isPresent(raw['percentMax'])
          ? '${_jsString(raw['percent'])}-${_jsString(raw['percentMax'])}%'
          : '${_jsString(raw['percent'])}%',
    );
  }
  if (_isPresent(raw['weight'])) parts.add('${_jsString(raw['weight'])}${_asText(raw['unit']) ?? ''}');
  if (_isPresent(raw['rpeMin'])) {
    parts.add(
      _isPresent(raw['rpeMax'])
          ? 'RPE ${_jsString(raw['rpeMin'])}-${_jsString(raw['rpeMax'])}'
          : 'RPE ${_jsString(raw['rpeMin'])}',
    );
  }
  final note = _asText(raw['note']);
  if (note != null) parts.add(note);
  return parts.isEmpty ? 'A set with no details' : parts.join(' ');
}

Json? _normalizeSet(Json raw, String location, _Context ctx) {
  final unreadable = <String>{for (final v in _asArray(raw['unreadable'])) ?_asText(v)};
  final notes = <String>[];
  final keepNote = _asText(raw['note']);
  if (keepNote != null) notes.add(keepNote);
  void asPrinted(String label, Object? value, String field) {
    notes.add('$label as printed: ${_asText(value) ?? (value == null ? 'undefined' : jsonEncode(value))}');
    unreadable.add(field);
  }

  final percentValue = _parseValue(raw['percent']);
  final percentMaxValue = _parseValue(raw['percentMax']);
  final percent = _inRange(percentValue.low, 0.5, 200) ? percentValue.low : null;
  final weightValue = _parseValue(raw['weight']).low;
  final weight = _inRange(weightValue, 0.25, 2000) ? weightValue : null;
  if (percent == null && weight == null) {
    // A load that was printed but couldn't be read must not become "choose
    // load": the user would lose the prescription without noticing. A set
    // with no load at all is an open set, as long as it prescribes something
    // (reps, or wording such as "max reps" in its note).
    final unreadableLoad = unreadable.contains('load') || _isPresent(raw['percent']) || _isPresent(raw['weight']);
    if (unreadableLoad || (!_isPresent(raw['reps']) && keepNote == null)) {
      ctx.unstructured.add({
        'location': location,
        'originalText': '${_describeSet(raw)}${unreadableLoad ? ' (load could not be read)' : ''}',
      });
      return null;
    }
  }

  final set = <String, Object?>{'sets': 1};

  final setsValue = _parseValue(raw['sets']).low;
  if (setsValue != null && _isInt(setsValue) && _inRange(setsValue, 1, 50)) {
    set['sets'] = setsValue.toInt();
  } else if (_isPresent(raw['sets'])) {
    asPrinted('Sets', raw['sets'], 'sets');
  }

  final repsValue = _parseValue(raw['reps']);
  final repsMaxRaw = repsValue.high ?? _parseValue(raw['repsMax']).low;
  bool validReps(num? n) => n != null && _isInt(n) && _inRange(n, 1, 1000);
  if (validReps(repsValue.low)) {
    final reps = repsValue.low!.toInt();
    set['reps'] = reps;
    if (validReps(repsMaxRaw) && repsMaxRaw! >= reps) {
      if (repsMaxRaw > reps) set['repsMax'] = repsMaxRaw.toInt();
    } else if (_isPresent(raw['repsMax'])) {
      asPrinted('Rep range top', raw['repsMax'], 'reps');
    }
  } else if (_isPresent(raw['reps'])) {
    asPrinted('Reps', raw['reps'], 'reps');
  }

  if (percent != null) {
    set['percent'] = percent;
    final top = percentValue.high ?? percentMaxValue.low;
    if (_inRange(top, percent, 200)) {
      if (top! > percent) set['percentMax'] = top;
    } else if (_isPresent(raw['percentMax']) || percentValue.high != null) {
      asPrinted('Percentage range top', raw['percentMax'] ?? raw['percent'], 'load');
    }
    // A percentage scales to the lifter, so it wins, but the printed load stays visible.
    if (weight != null) notes.add('Printed load: ${_jsString(weight)}${_normalizeUnit(raw['unit']) ?? ''}');
  } else if (weight != null) {
    set['weight'] = weight;
    final unit = _normalizeUnit(raw['unit']);
    if (unit != null) set['unit'] = unit;
  } else {
    set['openLoad'] = true;
  }

  bool validRpe(num? n) => _inRange(n, 1, 10) && _isInt(n! * 2);
  final rpeRaw = raw['rpeMin'] ?? raw['rpe'];
  final rpeValue = _parseValue(rpeRaw);
  final rpeTop = rpeValue.high ?? _parseValue(raw['rpeMax']).low;
  if (validRpe(rpeValue.low)) {
    set['rpeMin'] = rpeValue.low;
    if (validRpe(rpeTop) && rpeTop! >= rpeValue.low!) {
      if (rpeTop > rpeValue.low!) set['rpeMax'] = rpeTop;
    } else if (_isPresent(raw['rpeMax'])) {
      asPrinted('RPE range top', raw['rpeMax'], 'rpe');
    }
  } else if (_isPresent(rpeRaw)) {
    asPrinted('RPE', rpeRaw, 'rpe');
  }

  final basis = _asText(raw['basisExercise']);
  if (basis != null && set['percent'] != null) {
    set['basisExercise'] = {'name': basis, 'match': ctx.match(basis, null, null)};
  }

  if (notes.isNotEmpty) set['note'] = _truncate(notes.join('. '), _maxText);
  if (unreadable.isNotEmpty) set['unreadable'] = unreadable.toList();
  return set;
}

Json? _normalizeExercise(Json raw, String dayLocation, _Context ctx) {
  final name = _asText(raw['name']);
  if (name == null) {
    final prescriptions = _asObjects(raw['prescriptions']);
    if (prescriptions.isNotEmpty) {
      ctx.unstructured.add({
        'location': dayLocation,
        'originalText': 'Unnamed exercise: ${prescriptions.map(_describeSet).join('; ')}',
      });
    }
    return null;
  }

  final location = '$dayLocation, $name';
  final sets = [
    for (final p in _asArray(raw['prescriptions']))
      if (_asObject(p) case final obj?) ?_normalizeSet(obj, location, ctx),
  ];
  final notes = _asText(raw['notes']);
  return {'name': name, 'match': ctx.match(name, raw['match'], raw['confidence']), 'notes': ?notes, 'sets': sets};
}

Json _normalizeSession(Json raw, String location, _Context ctx) {
  final title = _asText(raw['title']);
  final notes = _asText(raw['notes']);
  final exercises = [
    for (final e in _asArray(raw['exercises']))
      if (_asObject(e) case final obj?) ?_normalizeExercise(obj, location, ctx),
  ];
  return {'title': ?title, 'notes': ?notes, 'exercises': exercises};
}

List<Json> _sessionsOf(Json day) => (day['sessions'] as List).cast<Json>();
List<Json> _exercisesOf(Json session) => (session['exercises'] as List).cast<Json>();

/// Every exercise of a day, session by session.
List<Json> dayExercises(Json day) => [for (final s in _sessionsOf(day)) ..._exercisesOf(s)];

/// At most [kMaxSessionsPerDay] sessions: any beyond go into the last one, in
/// order, and an unstructured entry says so, so nothing is silently merged.
List<Json> _capSessions(List<Json> sessions, String location, _Context ctx) {
  if (sessions.length <= kMaxSessionsPerDay) return sessions;
  final kept = sessions.sublist(0, kMaxSessionsPerDay - 1);
  final rest = sessions.sublist(kMaxSessionsPerDay - 1);
  final titles = [
    for (var i = 0; i < rest.length; i++) (rest[i]['title'] as String?) ?? 'Session ${kMaxSessionsPerDay + i}',
  ];
  final notes = [for (final s in rest) ?s['notes'] as String?].join('\n');
  ctx.unstructured.add({
    'location': location,
    'originalText':
        '${sessions.length} sessions on one day; a day holds $kMaxSessionsPerDay, so ${titles.join(', ')} '
        'are combined into one.',
  });
  return [
    ...kept,
    {
      'title': titles.join(' / '),
      if (notes.isNotEmpty) 'notes': notes,
      'exercises': [for (final s in rest) ..._exercisesOf(s)],
    },
  ];
}

Json _normalizeDay(Json raw, String location, _Context ctx) {
  final title = _asText(raw['title']);
  final weekday = _normalizeWeekday(raw['weekday']);
  final notes = _asText(raw['notes']);
  final dayLocation = title != null ? '$location, $title' : location;
  // A day of 2–3 sessions lists them in "sessions"; a day of one lists its
  // exercises directly, which keeps the common case short.
  final rawSessions = _asObjects(raw['sessions']);
  final sessions = rawSessions.isNotEmpty
      ? _capSessions(
          [
            for (var i = 0; i < rawSessions.length; i++)
              _normalizeSession(
                rawSessions[i],
                rawSessions.length > 1
                    ? '$dayLocation, ${_asText(rawSessions[i]['title']) ?? 'Session ${i + 1}'}'
                    : dayLocation,
                ctx,
              ),
          ],
          dayLocation,
          ctx,
        )
      : [
          _normalizeSession({'exercises': raw['exercises']}, dayLocation, ctx),
        ];
  final day = <String, Object?>{
    'title': ?title,
    'weekday': ?weekday,
    'isRestDay': false,
    'notes': ?notes,
    'sessions': sessions,
  };
  // A "rest day" with exercises on it is not a rest day.
  day['isRestDay'] = raw['isRestDay'] == true && dayExercises(day).isEmpty;
  return day;
}

/// Splits a week of numbered days longer than a week ("Day 1" … "Day 20") into
/// weeks of seven, in order, before its days are read, so the locations in
/// flagged content name the week each day ends up in. A "Day N" title restarts
/// at Day 1 in each week. A weekday-named week is left whole: [_fillRestDays]
/// makes it one calendar week.
List<Json> _splitRawWeek(Json raw) {
  final days = _asArray(raw['days']);
  final weekdayNamed = days.isNotEmpty && days.every((d) => _normalizeWeekday(_asObject(d)?['weekday']) != null);
  if (weekdayNamed || days.length <= kMaxDaysPerWeek) return [raw];
  final weeks = <Json>[];
  for (var start = 0; start < days.length; start += kMaxDaysPerWeek) {
    final chunk = days.sublist(start, (start + kMaxDaysPerWeek).clamp(0, days.length));
    weeks.add({
      // The label names the program's week, so only its first part keeps it.
      if (start == 0 && raw.containsKey('label')) 'label': raw['label'],
      'days': [
        for (var i = 0; i < chunk.length; i++)
          switch (_asObject(chunk[i])) {
            final obj? when _numberedDay.hasMatch(_asText(obj['title']) ?? '') => {...obj, 'title': 'Day ${i + 1}'},
            _ => chunk[i],
          },
      ],
    });
  }
  return weeks;
}

List<Json> _daysOf(Json week) => (week['days'] as List).cast<Json>();

/// Backstop for a week still over 7 days after normalizing: weeks of seven.
List<Json> _splitWeek(Json week) {
  final days = _daysOf(week);
  if (days.length <= kMaxDaysPerWeek) return [week];
  final label = week['label'] as String?;
  return [
    for (var start = 0; start < days.length; start += kMaxDaysPerWeek)
      {
        if (start == 0 && label != null && label.isNotEmpty) 'label': label,
        'days': days.sublist(start, (start + kMaxDaysPerWeek).clamp(0, days.length)),
      },
  ];
}

/// Several entries for one weekday (AM and PM listed as separate days) as one
/// day, since a week holds one day per weekday: each entry's sessions become
/// that day's sessions, in order, titled by the entry when it has a title and
/// the session has none. Over [kMaxSessionsPerDay], [_capSessions] combines
/// the rest.
Json _mergeSessions(List<Json> entries, String location, _Context ctx) {
  if (entries.length == 1) return entries.first;
  final sessions = [
    for (final d in entries)
      for (final s in _sessionsOf(d))
        () {
          final single = _sessionsOf(d).length == 1;
          final title = (s['title'] as String?) ?? (single ? d['title'] as String? : null);
          // A day's notes describe its one session when it's an entry of its own.
          final notes = [
            if (single) ?d['notes'] as String?,
            ?s['notes'] as String?,
          ].where((n) => n.isNotEmpty).join('\n');
          return <String, Object?>{
            'title': ?title,
            if (notes.isNotEmpty) 'notes': notes,
            'exercises': s['exercises'],
          };
        }(),
  ];
  final merged = <String, Object?>{
    'weekday': entries.first['weekday'],
    'isRestDay': false,
    'sessions': _capSessions(sessions, location, ctx),
  };
  merged['isRestDay'] = dayExercises(merged).isEmpty && entries.every((d) => d['isRestDay'] == true);
  return merged;
}

/// Makes a weekday-named week its seven days, Monday to Sunday: inserts the
/// rest days it leaves out, so the sessions keep their weekdays, and makes
/// several entries on one weekday that day's sessions. Only applies when every
/// day names its weekday.
Json _fillRestDays(Json week, String weekLocation, _Context ctx) {
  final days = _daysOf(week);
  if (days.isEmpty || days.any((d) => d['weekday'] == null)) return week;
  return {
    ...week,
    'days': [
      for (final weekday in _weekdays)
        switch (days.where((d) => d['weekday'] == weekday).toList()) {
          final onDay when onDay.isNotEmpty => _mergeSessions(onDay, '$weekLocation, ${_capitalized(weekday)}', ctx),
          _ => {
            'weekday': weekday,
            'isRestDay': true,
            'sessions': [
              {'exercises': <Json>[]},
            ],
          },
        },
    ],
  };
}

bool _hasContent(Json day) => dayExercises(day).isNotEmpty;

/// Parses the model's text, tolerating Markdown fences and surrounding prose.
/// Null when there's no JSON object in it.
Object? parseModelJson(String text) {
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  try {
    return jsonDecode(text.substring(start, end + 1));
  } on FormatException {
    return null;
  }
}

/// Normalizes the model's parsed reply ([parseModelJson]) against the lifter's
/// [catalog]. [requestedType] is what the lifter said the file is, if anything.
NormalizeOutcome normalizeImportResult(
  Object? rawResult,
  List<CatalogExercise> catalog, [
  ImportType? requestedType,
]) {
  final raw = _asObject(rawResult);
  if (raw == null) return const NormalizeInvalid();

  final ctx = _Context(ExerciseCatalog(catalog));
  final rawWeeks = [for (final w in _asObjects(raw['weeks'])) ..._splitRawWeek(w)];
  final isProgramShaped = rawWeeks.length > 1;

  var weeks = <Json>[
    for (var weekIndex = 0; weekIndex < rawWeeks.length; weekIndex++)
      () {
        final w = rawWeeks[weekIndex];
        final label = _asText(w['label']);
        final weekLocation = label ?? (isProgramShaped ? 'Week ${weekIndex + 1}' : 'Workout');
        final rawDays = _asArray(w['days']);
        final days = <Json>[
          for (var dayIndex = 0; dayIndex < rawDays.length; dayIndex++)
            if (_asObject(rawDays[dayIndex]) case final obj?)
              () {
                final weekday = _normalizeWeekday(obj['weekday']);
                final where = weekday != null
                    ? '$weekLocation, ${_capitalized(weekday)}'
                    : '$weekLocation, Day ${dayIndex + 1}';
                return _normalizeDay(obj, where, ctx);
              }(),
        ];
        return <String, Object?>{'label': ?label, 'days': days};
      }(),
  ];

  final fromModel = <Json>[
    for (final u in _asArray(raw['unstructured']))
      if (_asText(_asObject(u)?['originalText'] ?? (u is Map ? null : u)) case final originalText?)
        {'location': ?(_asObject(u) == null ? null : _asText(_asObject(u)!['location'])), 'originalText': originalText},
  ];

  final trainingDays = [
    for (final w in weeks)
      for (final d in _daysOf(w))
        if (_hasContent(d)) d,
  ];
  if (trainingDays.isEmpty && fromModel.isEmpty && ctx.unstructured.isEmpty) return const NormalizeNoWorkout();

  final rawType = raw['type'];
  final detectedType = rawType == 'workout' && trainingDays.length <= 1
      ? ImportType.workout
      : rawType == 'program'
      ? ImportType.program
      : trainingDays.length > 1
      ? ImportType.program
      : ImportType.workout;
  final type = requestedType ?? detectedType;

  if (type == ImportType.workout) {
    // Backstop for a re-run as a workout: one day holding everything, in order.
    final onlyTitle = trainingDays.length == 1 ? trainingDays.first['title'] as String? : null;
    final notes = [for (final d in trainingDays) ?d['notes'] as String?].join('\n');
    final merged = <String, Object?>{
      'title': ?onlyTitle,
      'isRestDay': false,
      'sessions': [
        {
          'exercises': [for (final d in trainingDays) ...dayExercises(d)],
        },
      ],
      if (notes.isNotEmpty) 'notes': notes,
    };
    weeks = [
      {
        'days': [merged],
      },
    ];
  } else {
    weeks = [
      for (var i = 0; i < weeks.length; i++)
        ..._splitWeek(
          _fillRestDays(
            weeks[i],
            (weeks[i]['label'] as String?) ?? (isProgramShaped ? 'Week ${i + 1}' : 'Workout'),
            ctx,
          ),
        ),
    ];
  }

  // Read after _fillRestDays, which can add to ctx.unstructured.
  final unstructured = [...fromModel, ...ctx.unstructured];
  final allExercises = [
    for (final w in weeks)
      for (final d in _daysOf(w)) ...dayExercises(d),
  ];
  final allSets = [for (final e in allExercises) ...(e['sets'] as List).cast<Json>()];
  final title = _asText(raw['title']);
  final description = _asText(raw['description']);
  return NormalizeOk({
    'schemaVersion': 2,
    'type': type.name,
    if (title != null) 'title': _truncate(title, 200),
    'description': ?description,
    if (description != null && raw['descriptionGenerated'] == true) 'descriptionGenerated': true,
    'weeks': weeks,
    'unstructured': unstructured,
    'flags': {
      'handwritten': raw['handwritten'] == true,
      'needsUnit': allSets.any((s) => s['weight'] != null && s['unit'] == null),
      'uncertainExercises':
          allExercises.any((e) => e['match'] == null || (e['match'] as Json)['confidence'] == 'low') ||
          allSets.any((s) => s['basisExercise'] != null && (s['basisExercise'] as Json)['match'] == null),
      'unreadableValues': allSets.any((s) => (s['unreadable'] as List?)?.isNotEmpty ?? false),
      'unstructuredContent': unstructured.isNotEmpty,
    },
  }, detectedType);
}
