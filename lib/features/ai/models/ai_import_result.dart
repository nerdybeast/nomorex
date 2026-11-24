import '../../../core/utils/exercise_name.dart';
import '../../../core/utils/weight_converter.dart';
import '../../exercises/models/exercise.dart';

/// What an import read, as stored in `ai_import_results.payload` by the
/// `startAiImport` flow (`supabase/functions/ai/ai_import/normalize.ts`).
///
/// Parsed only for display. The review is applied to the stored JSON itself
/// ([buildReviewedPayload]), so fields this app doesn't render still reach
/// `ai_import_accept` unchanged.
class AiImportResult {
  const AiImportResult({
    required this.type,
    required this.weeks,
    required this.unstructured,
    required this.handwritten,
    required this.raw,
    this.title,
    this.description,
    this.descriptionGenerated = false,
  });

  factory AiImportResult.fromJson(Map<String, dynamic> json) => AiImportResult(
    type: json['type'] == 'program' ? 'program' : 'workout',
    title: _text(json['title']),
    description: _text(json['description']),
    descriptionGenerated: json['descriptionGenerated'] == true,
    weeks: [for (final w in _objects(json['weeks'])) ImportWeek.fromJson(w)],
    unstructured: [for (final u in _objects(json['unstructured'])) UnstructuredItem.fromJson(u)],
    handwritten: (json['flags'] as Map?)?['handwritten'] == true,
    raw: json,
  );

  /// `workout` or `program`: what the user asked for, else what was found.
  final String type;
  final String? title;

  /// The file's own introduction, or one the model wrote when it had none
  /// ([descriptionGenerated]). Results stored before descriptions have none.
  final String? description;

  /// [description] was written by the model rather than copied from the file.
  final bool descriptionGenerated;

  final List<ImportWeek> weeks;

  /// Content that couldn't be turned into sets, in its original wording.
  final List<UnstructuredItem> unstructured;

  /// Written by hand, so every weight needs checking.
  final bool handwritten;
  final Map<String, dynamic> raw;

  bool get isProgram => type == 'program';

  Iterable<ImportDay> get days => weeks.expand((w) => w.days);
  Iterable<ImportExercise> get exercises => days.expand((d) => d.exercises);
  Iterable<ImportSet> get sets => exercises.expand((e) => e.sets);

  /// An absolute weight was read with no unit printed beside it, so the user
  /// must say which unit those weights are in before saving.
  bool get needsUnit => sets.any((s) => s.needsUnit);

  /// Names whose exercise wasn't matched exactly, each listed once with how
  /// often it appears, including as a percentage's basis lift. Fixing one
  /// fixes every occurrence.
  List<ExerciseToCheck> get exercisesToCheck {
    final byKey = <String, ExerciseToCheck>{};
    void add(String name, ImportMatch? match) {
      if (match?.confidence == 'exact') return;
      final key = normalizeExerciseName(name);
      final existing = byKey[key];
      byKey[key] = existing == null
          ? ExerciseToCheck(key: key, name: name, match: match, occurrences: 1)
          : existing.withAnotherOccurrence();
    }

    for (final exercise in exercises) {
      add(exercise.name, exercise.match);
      for (final set in exercise.sets) {
        if (set.basisName case final basis?) add(basis, set.basisMatch);
      }
    }
    return byKey.values.toList();
  }
}

class ImportWeek {
  const ImportWeek({required this.days, this.label});

  factory ImportWeek.fromJson(Map<String, dynamic> json) =>
      ImportWeek(label: _text(json['label']), days: [for (final d in _objects(json['days'])) ImportDay.fromJson(d)]);

  final String? label;
  final List<ImportDay> days;
}

class ImportDay {
  const ImportDay({required this.isRestDay, required this.sessions, this.title, this.weekday, this.notes});

  /// Reads a day's `sessions` (import schema 2), or else its `exercises` as
  /// one session (schema 1, stored before days had sessions).
  factory ImportDay.fromJson(Map<String, dynamic> json) {
    final sessions = _objects(json['sessions']);
    return ImportDay(
      title: _text(json['title']),
      weekday: _text(json['weekday']),
      isRestDay: json['isRestDay'] == true,
      notes: _text(json['notes']),
      sessions: sessions.isNotEmpty
          ? [for (final s in sessions) ImportSession.fromJson(s)]
          : [ImportSession.fromJson({'exercises': json['exercises']})],
    );
  }

  final String? title;

  /// Lowercase English weekday, e.g. `monday`.
  final String? weekday;
  final bool isRestDay;
  final String? notes;

  /// At least one; more than one is a day of several workouts (AM, PM …).
  final List<ImportSession> sessions;

  /// Every exercise of the day, session by session.
  List<ImportExercise> get exercises => [for (final s in sessions) ...s.exercises];
}

/// One of a day's sessions, each its own workout once the program starts.
class ImportSession {
  const ImportSession({required this.exercises, this.title, this.notes});

  factory ImportSession.fromJson(Map<String, dynamic> json) => ImportSession(
    title: _text(json['title']),
    notes: _text(json['notes']),
    exercises: [for (final e in _objects(json['exercises'])) ImportExercise.fromJson(e)],
  );

  final String? title;
  final String? notes;
  final List<ImportExercise> exercises;

  /// The title, or "Session N" for the session at [index] (0-based).
  String label(int index) => title ?? 'Session ${index + 1}';
}

class ImportExercise {
  const ImportExercise({required this.name, required this.sets, this.match, this.notes});

  factory ImportExercise.fromJson(Map<String, dynamic> json) => ImportExercise(
    name: _text(json['name']) ?? '',
    match: ImportMatch.fromJson(json['match']),
    notes: _text(json['notes']),
    sets: [for (final s in _objects(json['sets'])) ImportSet.fromJson(s)],
  );

  /// The name as printed.
  final String name;

  /// The catalog exercise it was matched to, or null for none.
  final ImportMatch? match;
  final String? notes;
  final List<ImportSet> sets;
}

class ImportMatch {
  const ImportMatch({required this.exerciseId, required this.name, required this.confidence});

  static ImportMatch? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['exerciseId'];
    final name = json['name'];
    if (id is! String || name is! String) return null;
    return ImportMatch(exerciseId: id, name: name, confidence: json['confidence'] as String? ?? 'low');
  }

  final String exerciseId;
  final String name;

  /// `exact` (the printed name is in the catalog), `high` or `low`.
  final String confidence;
}

/// One prescription line. [sets] identical sets of [reps] at a percentage,
/// an absolute weight, or no prescribed load ([openLoad]).
class ImportSet {
  const ImportSet({
    required this.sets,
    this.reps,
    this.repsMax,
    this.percent,
    this.percentMax,
    this.weight,
    this.unit,
    this.openLoad = false,
    this.rpeMin,
    this.rpeMax,
    this.basisName,
    this.basisMatch,
    this.note,
    this.unreadable = const [],
  });

  factory ImportSet.fromJson(Map<String, dynamic> json) {
    final basis = json['basisExercise'];
    return ImportSet(
      sets: (json['sets'] as num?)?.toInt() ?? 1,
      reps: (json['reps'] as num?)?.toInt(),
      repsMax: (json['repsMax'] as num?)?.toInt(),
      percent: (json['percent'] as num?)?.toDouble(),
      percentMax: (json['percentMax'] as num?)?.toDouble(),
      weight: (json['weight'] as num?)?.toDouble(),
      unit: switch (json['unit']) {
        'kg' => 'kg',
        'lb' => 'lb',
        _ => null,
      },
      openLoad: json['openLoad'] == true,
      rpeMin: (json['rpeMin'] as num?)?.toDouble(),
      rpeMax: (json['rpeMax'] as num?)?.toDouble(),
      basisName: basis is Map ? _text(basis['name']) : null,
      basisMatch: basis is Map ? ImportMatch.fromJson(basis['match']) : null,
      note: _text(json['note']),
      unreadable: [for (final u in (json['unreadable'] as List?) ?? const []) ?_text(u)],
    );
  }

  final int sets;
  final int? reps;
  final int? repsMax;
  final double? percent;
  final double? percentMax;

  /// An absolute load as printed, in [unit].
  final double? weight;

  /// `kg` or `lb` when printed beside the weight.
  final String? unit;

  /// No load is prescribed, so the lifter picks the weight on the day, as for
  /// "3x8 light by feel". Saved as an open set (`weight_mode = 'open'`).
  final bool openLoad;
  final double? rpeMin;
  final double? rpeMax;

  /// The lift a percentage is taken of, when it isn't this exercise.
  final String? basisName;
  final ImportMatch? basisMatch;
  final String? note;

  /// Fields that were on the page but couldn't be read: `sets`, `reps`,
  /// `load` or `rpe`.
  final List<String> unreadable;

  bool get isAbsolute => percent == null && weight != null;
  bool get needsUnit => isAbsolute && unit == null;
}

class UnstructuredItem {
  const UnstructuredItem({required this.originalText, this.location});

  factory UnstructuredItem.fromJson(Map<String, dynamic> json) =>
      UnstructuredItem(location: _text(json['location']), originalText: _text(json['originalText']) ?? '');

  /// Where it was, such as "Week 1, Monday, Bench Press".
  final String? location;
  final String originalText;
}

/// An exercise name that needs the user's attention. See
/// [AiImportResult.exercisesToCheck].
class ExerciseToCheck {
  const ExerciseToCheck({required this.key, required this.name, required this.match, required this.occurrences});

  final String key;
  final String name;

  /// The model's guess, or null when nothing in the catalog matched.
  final ImportMatch? match;
  final int occurrences;

  ExerciseToCheck withAnotherOccurrence() =>
      ExerciseToCheck(key: key, name: name, match: match, occurrences: occurrences + 1);
}

/// How the user fixed an exercise name. Applies to every occurrence of it.
sealed class ExerciseFix {
  const ExerciseFix();
}

/// Use an exercise already in the user's catalog.
class UseExistingExercise extends ExerciseFix {
  const UseExistingExercise(this.exercise);
  final Exercise exercise;
}

/// Save it as a custom exercise with [name]. Nothing is created until the
/// import is accepted, and then only if no exercise of that name exists.
class CreateCustomExercise extends ExerciseFix {
  const CreateCustomExercise(this.name);
  final String name;
}

/// The stored result with the user's review applied, ready for
/// `ai_import_accept`:
/// - [title] replaces the read title (blank leaves the server's fallback);
/// - each [fixes] entry replaces the match on every exercise and basis lift
///   of that name;
/// - each absolute load becomes `weightKg`, in its printed unit or else
///   [unit]. The server refuses a set that still has only `weight`.
///
/// Throws [StateError] if an absolute load has no printed unit and [unit] is
/// null; the screen keeps Accept disabled until one is chosen.
Map<String, dynamic> buildReviewedPayload(
  Map<String, dynamic> raw, {
  required String title,
  String? description,
  required Map<String, ExerciseFix> fixes,
  String? unit,
}) {
  Map<String, dynamic> fixed(Map<String, dynamic> named) {
    final fix = fixes[normalizeExerciseName(named['name'] as String? ?? '')];
    return switch (fix) {
      null => named,
      UseExistingExercise(:final exercise) => {
        ...named,
        'match': {'exerciseId': exercise.id, 'name': exercise.name, 'confidence': 'exact'},
      },
      CreateCustomExercise(:final name) => {...named, 'name': name.trim(), 'match': null},
    };
  }

  Map<String, dynamic> reviewSet(Map<String, dynamic> set) {
    final out = Map<String, dynamic>.of(set);
    if (out['basisExercise'] case final Map basis) {
      out['basisExercise'] = fixed(Map<String, dynamic>.from(basis));
    }
    final weight = (out['weight'] as num?)?.toDouble();
    if (out['percent'] == null && weight != null) {
      final setUnit = switch (out['unit']) {
        'kg' => 'kg',
        'lb' => 'lb',
        _ => unit,
      };
      if (setUnit == null) throw StateError('a weight has no unit');
      out['weightKg'] = setUnit == 'lb' ? _roundKg(lbsToKg(weight)) : weight;
      out.remove('weight');
      out.remove('unit');
    }
    return out;
  }

  List<Map<String, dynamic>> reviewExercises(Object? exercises) => [
    for (final exercise in _objects(exercises))
      {
        ...fixed(exercise),
        'sets': [for (final set in _objects(exercise['sets'])) reviewSet(set)],
      },
  ];

  final trimmed = title.trim();
  final described = description?.trim();
  return {
    ...raw,
    'title': trimmed.isEmpty ? null : trimmed,
    // As the user left it: cleared means none. Null leaves the stored one.
    if (described != null) 'description': described.isEmpty ? null : described,
    'weeks': [
      for (final week in _objects(raw['weeks']))
        {
          ...week,
          'days': [
            for (final day in _objects(week['days']))
              {
                ...day,
                // A schema 2 day holds its exercises in sessions; a schema 1
                // day (stored before #175) holds them itself.
                if (day['sessions'] is List)
                  'sessions': [
                    for (final session in _objects(day['sessions']))
                      {...session, 'exercises': reviewExercises(session['exercises'])},
                  ]
                else
                  'exercises': reviewExercises(day['exercises']),
              },
          ],
        },
    ],
  };
}

/// Three decimals: 225 lb is 102.058 kg, which reads back as 225 lb.
double _roundKg(double kg) => (kg * 1000).roundToDouble() / 1000;

String? _text(Object? v) {
  if (v is num) return v.toString();
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

List<Map<String, dynamic>> _objects(Object? v) => [
  if (v is List)
    for (final item in v)
      if (item is Map) Map<String, dynamic>.from(item),
];
