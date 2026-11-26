// Ported case for case from supabase/functions/ai/ai_import/normalize_test.ts.
// Keep the two in step while the hosted path exists.
import 'package:import_pipeline/import_pipeline.dart';
import 'package:test/test.dart';

const catalog = [
  CatalogExercise(id: 'squat', name: 'Back Squat'),
  CatalogExercise(id: 'front', name: 'Front Squat'),
  CatalogExercise(id: 'cj', name: 'Clean & Jerk'),
];

Json workout(List<Object?> prescriptions, [Json exercise = const {}]) => {
  'type': 'workout',
  'weeks': [
    {
      'days': [
        {
          'exercises': [
            {'name': 'Back Squat', 'prescriptions': prescriptions, ...exercise},
          ],
        },
      ],
    },
  ],
};

Json ok(Object? raw, [ImportType? requested, List<CatalogExercise> cat = catalog]) {
  final out = normalizeImportResult(raw, cat, requested);
  if (out is! NormalizeOk) throw StateError('expected ok, got $out');
  return out.result;
}

List<Json> weeksOf(Json r) => (r['weeks'] as List).cast<Json>();
List<Json> daysOf(Json week) => (week['days'] as List).cast<Json>();
List<Json> sessionsOf(Json day) => (day['sessions'] as List).cast<Json>();
List<Json> unstructuredOf(Json r) => (r['unstructured'] as List).cast<Json>();
Json flagsOf(Json r) => r['flags'] as Json;
Json firstExercise(Json r) => dayExercises(daysOf(weeksOf(r)[0])[0])[0];
List<Json> setsOf(Json exercise) => (exercise['sets'] as List).cast<Json>();
Json firstSet(Json r) => setsOf(firstExercise(r))[0];

Json trainingDay(String weekday) => {
  'weekday': weekday,
  'exercises': [
    {
      'name': 'Back Squat',
      'prescriptions': [
        {'sets': 1, 'reps': 1, 'percent': 90},
      ],
    },
  ],
};

void main() {
  test('keeps ranges, RPE and the printed unit', () {
    final r = ok(
      workout([
        {'sets': 3, 'reps': 7, 'repsMax': 9, 'percent': 67, 'percentMax': 72.5, 'rpeMin': 6, 'rpeMax': 7},
        {'sets': 2, 'reps': 5, 'weight': 100, 'unit': 'lbs'},
      ]),
    );
    expect(firstSet(r), {'sets': 3, 'reps': 7, 'repsMax': 9, 'percent': 67, 'percentMax': 72.5, 'rpeMin': 6, 'rpeMax': 7});
    expect(setsOf(firstExercise(r))[1], {'sets': 2, 'reps': 5, 'weight': 100, 'unit': 'lb'});
    expect(flagsOf(r)['needsUnit'], false);
  });

  test('accepts loose values the model sometimes returns', () {
    final r = ok(
      workout([
        {'sets': '3', 'reps': '5-8', 'percent': '67-72.5%', 'rpeMin': '6-7'},
      ]),
    );
    expect(firstSet(r), {'sets': 3, 'reps': 5, 'repsMax': 8, 'percent': 67, 'percentMax': 72.5, 'rpeMin': 6, 'rpeMax': 7});
  });

  test('a weight with no real unit is left without one and flagged', () {
    final r = ok(
      workout([
        {'sets': 3, 'reps': 5, 'weight': 100, 'unit': 'none'},
      ]),
    );
    expect(firstSet(r), {'sets': 3, 'reps': 5, 'weight': 100});
    expect(flagsOf(r)['needsUnit'], true);
  });

  test('a range narrowed to one number is a single value, as the database stores it', () {
    expect(
      firstSet(
        ok(
          workout([
            {'sets': 1, 'reps': 5, 'repsMax': 5, 'percent': 70, 'percentMax': 70},
          ]),
        ),
      ),
      {'sets': 1, 'reps': 5, 'percent': 70},
    );
  });

  test('a set with no load is an open set, keeping its reps, RPE and wording', () {
    final r = ok(
      workout([
        {'sets': 3, 'reps': 8, 'repsMax': 10, 'rpeMin': 8, 'note': 'light by feel'},
      ]),
    );
    expect(setsOf(firstExercise(r)), [
      {'sets': 3, 'reps': 8, 'repsMax': 10, 'rpeMin': 8, 'openLoad': true, 'note': 'light by feel'},
    ]);
    expect(unstructuredOf(r), isEmpty);
    expect(flagsOf(r)['unstructuredContent'], false);
    expect(flagsOf(r)['needsUnit'], false);
  });

  test('"max reps" with no load is an open set with the wording as its note', () {
    final r = ok(
      workout([
        {'sets': 3, 'note': 'max reps'},
      ]),
    );
    expect(firstSet(r), {'sets': 3, 'openLoad': true, 'note': 'max reps'});
    expect(unstructuredOf(r), isEmpty);
  });

  test('a set with no load, reps or wording is kept as flagged content, not dropped', () {
    final r = ok(
      workout([
        {'sets': 3},
      ]),
    );
    expect(setsOf(firstExercise(r)), isEmpty);
    expect(unstructuredOf(r)[0]['originalText'], '3 sets');
    expect((unstructuredOf(r)[0]['location'] as String).endsWith('Back Squat'), true);
  });

  test('a load marked unreadable is never an open set', () {
    final r = ok(
      workout([
        {
          'sets': 3,
          'reps': 5,
          'unreadable': ['load'],
        },
      ]),
    );
    expect(setsOf(firstExercise(r)), isEmpty);
    expect(unstructuredOf(r)[0]['originalText'], '3 x 5 (load could not be read)');
  });

  test('an open set has no basis lift', () {
    final r = ok(
      workout([
        {'sets': 3, 'reps': 8, 'basisExercise': 'Clean & Jerk'},
      ]),
    );
    expect(firstSet(r), {'sets': 3, 'reps': 8, 'openLoad': true});
    expect(flagsOf(r)['uncertainExercises'], false);
  });

  test('an unreadable load goes to flagged content', () {
    final r = ok(
      workout([
        {'sets': 3, 'reps': 5, 'weight': 'smudged'},
      ]),
    );
    expect(setsOf(firstExercise(r)), isEmpty);
    expect((unstructuredOf(r)[0]['originalText'] as String).contains('load could not be read'), true);
  });

  test('values that break the set rules become notes rather than failing the import', () {
    final r = ok(
      workout([
        {'sets': 3, 'reps': 8, 'repsMax': 5, 'percent': 70, 'rpeMin': 11},
        {'sets': 'lots', 'reps': 'AMRAP', 'percent': 70},
      ]),
    );
    expect(firstSet(r), {
      'sets': 3,
      'reps': 8,
      'percent': 70,
      'note': 'Rep range top as printed: 5. RPE as printed: 11',
      'unreadable': ['reps', 'rpe'],
    });
    expect(setsOf(firstExercise(r))[1], {
      'sets': 1,
      'percent': 70,
      'note': 'Sets as printed: lots. Reps as printed: AMRAP',
      'unreadable': ['sets', 'reps'],
    });
    expect(flagsOf(r)['unreadableValues'], true);
  });

  test('an inverted percentage range keeps the lower value and notes the printed one', () {
    final set = firstSet(
      ok(
        workout([
          {'sets': 1, 'reps': 5, 'percent': 80, 'percentMax': 70},
        ]),
      ),
    );
    expect(set['percent'], 80);
    expect(set['percentMax'], isNull);
    expect(set['unreadable'], ['load']);
  });

  test('a percentage wins over a printed load, which stays visible', () {
    final set = firstSet(
      ok(
        workout([
          {'sets': 1, 'reps': 5, 'percent': 80, 'weight': 100, 'unit': 'kg'},
        ]),
      ),
    );
    expect(set['percent'], 80);
    expect(set['weight'], isNull);
    expect(set['note'], 'Printed load: 100kg');
  });

  test('keeps values the model flagged as unreadable', () {
    final set = firstSet(
      ok(
        workout([
          {
            'sets': 3,
            'percent': 70,
            'unreadable': ['reps'],
          },
        ]),
      ),
    );
    expect(set, {
      'sets': 3,
      'percent': 70,
      'unreadable': ['reps'],
    });
  });

  test('flags a handwritten file only when the model says it is', () {
    final body = workout([
      {'sets': 3, 'reps': 5, 'percent': 80},
    ]);
    expect(flagsOf(ok({...body, 'handwritten': true}))['handwritten'], true);
    expect(flagsOf(ok(body))['handwritten'], false);
    expect(flagsOf(ok({...body, 'handwritten': 'maybe'}))['handwritten'], false);
  });

  test('a name already in the catalog is an exact match, ignoring case and spaces', () {
    final r = ok(
      workout(
        [
          {'sets': 1, 'reps': 1, 'percent': 90},
        ],
        {'name': '  back squat ', 'match': 'Front Squat'},
      ),
    );
    expect(firstExercise(r)['match'], {'exerciseId': 'squat', 'name': 'Back Squat', 'confidence': 'exact'});
    expect(flagsOf(r)['uncertainExercises'], false);
  });

  test('a suggested match carries the model confidence', () {
    final high = ok(
      workout(
        [
          {'sets': 1, 'reps': 1, 'percent': 90},
        ],
        {'name': 'Pause FS', 'match': 'front squat', 'confidence': 'high'},
      ),
    );
    expect(firstExercise(high)['match'], {'exerciseId': 'front', 'name': 'Front Squat', 'confidence': 'high'});
    expect(flagsOf(high)['uncertainExercises'], false);

    final low = ok(
      workout(
        [
          {'sets': 1, 'reps': 1, 'percent': 90},
        ],
        {'name': 'FS', 'match': 'Front Squat'},
      ),
    );
    expect((firstExercise(low)['match'] as Json)['confidence'], 'low');
    expect(flagsOf(low)['uncertainExercises'], true);
  });

  test('a suggestion that is not in the catalog is not a match', () {
    final r = ok(
      workout(
        [
          {'sets': 1, 'reps': 1, 'percent': 90},
        ],
        {'name': 'Zercher', 'match': 'Zercher Squat'},
      ),
    );
    expect(firstExercise(r)['match'], isNull);
    expect(flagsOf(r)['uncertainExercises'], true);
  });

  test('resolves a basis lift by name and flags one it cannot find', () {
    final r = ok(
      workout([
        {'sets': 1, 'reps': 1, 'percent': 75, 'basisExercise': 'clean & jerk'},
      ]),
    );
    expect(firstSet(r)['basisExercise'], {
      'name': 'clean & jerk',
      'match': {'exerciseId': 'cj', 'name': 'Clean & Jerk', 'confidence': 'exact'},
    });
    final unknown = ok(
      workout([
        {'sets': 1, 'reps': 1, 'percent': 75, 'basisExercise': 'best deadlift'},
      ]),
    );
    expect((firstSet(unknown)['basisExercise'] as Json)['match'], isNull);
    expect(flagsOf(unknown)['uncertainExercises'], true);
  });

  test('fills the rest days a weekday-named week leaves out', () {
    final r = ok({
      'type': 'program',
      'weeks': [
        {
          'days': [trainingDay('Friday'), trainingDay('monday'), trainingDay('wed')],
        },
      ],
    });
    expect(daysOf(weeksOf(r)[0]).map((d) => [d['weekday'], d['isRestDay']]).toList(), [
      ['monday', false],
      ['tuesday', true],
      ['wednesday', false],
      ['thursday', true],
      ['friday', false],
      ['saturday', true],
      ['sunday', true],
    ]);
  });

  test("two entries on one weekday become that day's two sessions", () {
    final am = {...trainingDay('monday'), 'title': 'AM', 'notes': 'Snatch focus'};
    final pm = {
      'weekday': 'monday',
      'title': 'PM',
      'exercises': [
        {
          'name': 'Front Squat',
          'prescriptions': [
            {'sets': 1, 'reps': 3, 'percent': 80},
          ],
        },
      ],
    };
    final r = ok({
      'type': 'program',
      'weeks': [
        {
          'days': [am, pm],
        },
      ],
    });
    expect(daysOf(weeksOf(r)[0]).length, 7);
    final monday = daysOf(weeksOf(r)[0])[0];
    expect(monday['title'], isNull);
    expect(
      sessionsOf(monday)
          .map((s) => [s['title'], s['notes'], (s['exercises'] as List).map((e) => (e as Json)['name']).toList()])
          .toList(),
      [
        [
          'AM',
          'Snatch focus',
          ['Back Squat'],
        ],
        [
          'PM',
          null,
          ['Front Squat'],
        ],
      ],
    );
    expect(unstructuredOf(r), isEmpty);
  });

  test("a day's sessions are kept apart, in order", () {
    final r = ok({
      'type': 'program',
      'weeks': [
        {
          'days': [
            {
              'weekday': 'monday',
              'notes': 'Two-a-day',
              'sessions': [
                {'title': 'AM', 'exercises': trainingDay('monday')['exercises']},
                {
                  'exercises': [
                    {
                      'name': 'Front Squat',
                      'prescriptions': [
                        {'reps': 3, 'percent': 80},
                      ],
                    },
                  ],
                },
              ],
            },
          ],
        },
      ],
    });
    final monday = daysOf(weeksOf(r)[0])[0];
    expect(monday['notes'], 'Two-a-day');
    expect(monday['isRestDay'], false);
    expect(sessionsOf(monday).map((s) => s['title']).toList(), ['AM', null]);
    expect(dayExercises(monday).map((e) => e['name']).toList(), ['Back Squat', 'Front Squat']);
  });

  test('a day with one session lists it as one', () {
    final r = ok({
      'type': 'program',
      'weeks': [
        {
          'days': [trainingDay('monday')],
        },
      ],
    });
    expect(r['schemaVersion'], 2);
    expect(sessionsOf(daysOf(weeksOf(r)[0])[0]).length, 1);
    // A rest day the week leaves out gets one empty session too.
    expect(sessionsOf(daysOf(weeksOf(r)[0])[1]), [
      {'exercises': <Object?>[]},
    ]);
  });

  test('a 4th session is combined into the 3rd, and says so', () {
    Json session(String title) => {'title': title, 'exercises': trainingDay('monday')['exercises']};
    final r = ok({
      'type': 'program',
      'weeks': [
        {
          'days': [
            {
              'weekday': 'monday',
              'sessions': ['A', 'B', 'C', 'D'].map(session).toList(),
            },
          ],
        },
      ],
    });
    final monday = daysOf(weeksOf(r)[0])[0];
    expect(sessionsOf(monday).map((s) => [s['title'], (s['exercises'] as List).length]).toList(), [
      ['A', 1],
      ['B', 1],
      ['C / D', 2],
    ]);
    expect(unstructuredOf(r).length, 1);
    expect(unstructuredOf(r)[0]['location'], 'Workout, Monday');
    expect(flagsOf(r)['unstructuredContent'], true);
  });

  test('four entries on one weekday fold into 3 sessions', () {
    Json entry(String title) => {...trainingDay('tuesday'), 'title': title};
    final r = ok({
      'type': 'program',
      'weeks': [
        {'days': ['1', '2', '3', '4'].map(entry).toList()},
      ],
    });
    final tuesday = daysOf(weeksOf(r)[0])[1];
    expect(sessionsOf(tuesday).map((s) => s['title']).toList(), ['1', '2', '3 / 4']);
    expect(unstructuredOf(r).map((u) => u['location']).toList(), ['Workout, Tuesday']);
  });

  test('a re-run as a workout puts every session in one', () {
    final r = ok({
      'type': 'program',
      'weeks': [
        {
          'days': [
            {
              'weekday': 'monday',
              'sessions': [
                {'title': 'AM', 'exercises': trainingDay('monday')['exercises']},
                {'title': 'PM', 'exercises': trainingDay('monday')['exercises']},
              ],
            },
            trainingDay('tuesday'),
          ],
        },
      ],
    }, ImportType.workout);
    expect(daysOf(weeksOf(r)[0]).length, 1);
    expect(sessionsOf(daysOf(weeksOf(r)[0])[0]).length, 1);
    expect((sessionsOf(daysOf(weeksOf(r)[0])[0])[0]['exercises'] as List).length, 3);
  });

  test('splits numbered days into weeks of seven, restarting the titles', () {
    final days = List.generate(
      20,
      (i) => i == 6 || i == 13
          ? {'title': 'Day ${i + 1}', 'isRestDay': true}
          : {'title': 'Day ${i + 1}', 'exercises': trainingDay('monday')['exercises']},
    );
    final r = ok({
      'type': 'program',
      'weeks': [
        {'label': 'Arm challenge', 'days': days},
      ],
    });
    expect(weeksOf(r).map((w) => daysOf(w).length).toList(), [7, 7, 6]);
    expect(weeksOf(r).map((w) => w['label']).toList(), ['Arm challenge', null, null]);
    expect(daysOf(weeksOf(r)[1]).map((d) => d['title']).toList(), [
      'Day 1',
      'Day 2',
      'Day 3',
      'Day 4',
      'Day 5',
      'Day 6',
      'Day 7',
    ]);
    expect(daysOf(weeksOf(r)[1])[6]['isRestDay'], true);
  });

  test('keeps a day title that is not a day number when splitting', () {
    final days = List.generate(
      8,
      (i) => {'title': i == 7 ? 'Test day' : 'Day ${i + 1}', 'exercises': trainingDay('monday')['exercises']},
    );
    final r = ok({
      'type': 'program',
      'weeks': [
        {'days': days},
      ],
    });
    expect(daysOf(weeksOf(r)[1]).map((d) => d['title']).toList(), ['Test day']);
  });

  test('names the split week in flagged content', () {
    final days = List.generate(
      9,
      (i) => {
        'title': 'Day ${i + 1}',
        'exercises': [
          {
            'name': 'Back Squat',
            'prescriptions': i == 8
                ? [
                    {'sets': 3, 'reps': 5, 'weight': 'smudged'},
                  ]
                : [
                    {'reps': 3, 'percent': 70},
                  ],
          },
        ],
      },
    );
    final r = ok({
      'type': 'program',
      'weeks': [
        {'days': days},
      ],
    });
    expect(weeksOf(r).length, 2);
    expect(unstructuredOf(r).any((u) => (u['location'] as String?)?.startsWith('Week 2, Day 2') ?? false), true);
  });

  test('adds no rest days when days are only numbered', () {
    final day = {'title': 'Day 1', 'exercises': trainingDay('monday')['exercises']};
    final r = ok({
      'type': 'program',
      'weeks': [
        {
          'days': [day, day],
        },
      ],
    });
    expect(daysOf(weeksOf(r)[0]).length, 2);
  });

  test('a rest day with exercises on it is not a rest day', () {
    final r = ok({
      'type': 'program',
      'weeks': [
        {
          'days': [
            {...trainingDay('monday'), 'isRestDay': true},
          ],
        },
      ],
    });
    expect(daysOf(weeksOf(r)[0])[0]['isRestDay'], false);
  });

  test('several training days labelled a workout are detected as a program', () {
    final out = normalizeImportResult({
      'type': 'workout',
      'weeks': [
        {
          'days': [trainingDay('monday'), trainingDay('tuesday')],
        },
      ],
    }, catalog);
    expect(out, isA<NormalizeOk>().having((o) => o.detectedType, 'detectedType', ImportType.program));
  });

  test('a re-run as a workout merges every day into one', () {
    final r = ok({
      'type': 'program',
      'weeks': [
        {
          'days': [trainingDay('monday'), trainingDay('tuesday')],
        },
      ],
    }, ImportType.workout);
    expect(r['type'], 'workout');
    expect(weeksOf(r).length, 1);
    expect(daysOf(weeksOf(r)[0]).length, 1);
    expect(dayExercises(daysOf(weeksOf(r)[0])[0]).length, 2);
  });

  test('a re-run as a program stays a program', () {
    expect(
      ok(
        workout([
          {'sets': 1, 'reps': 1, 'percent': 90},
        ]),
        ImportType.program,
      )['type'],
      'program',
    );
  });

  test('nothing to read is "no workout found"', () {
    expect(normalizeImportResult({'type': 'none', 'weeks': []}, catalog), isA<NormalizeNoWorkout>());
    expect(normalizeImportResult(<String, Object?>{}, catalog), isA<NormalizeNoWorkout>());
  });

  test('a file with only unstructured content is still a result', () {
    final out = normalizeImportResult({
      'type': 'none',
      'unstructured': [
        {'originalText': '10 min EMOM'},
      ],
    }, catalog);
    expect(out, isA<NormalizeOk>());
  });

  test('something other than an object is invalid', () {
    expect(normalizeImportResult(null, catalog), isA<NormalizeInvalid>());
    expect(normalizeImportResult([1, 2], catalog), isA<NormalizeInvalid>());
  });

  test('parses JSON inside a Markdown fence or surrounding prose', () {
    expect(parseModelJson('```json\n{"a": 1}\n```'), {'a': 1});
    expect(parseModelJson('Here it is: {"a": 1} Done.'), {'a': 1});
    expect(parseModelJson('{"a": '), isNull);
    expect(parseModelJson('no json'), isNull);
  });

  // The same cases as exercise_catalog.test.sql and exercise_name_test.dart.
  test('normalizeExerciseName matches the database and app rules', () {
    expect(normalizeExerciseName('  Clean   &  Jerk '), 'clean & jerk');
    expect(normalizeExerciseName('BACK\tSquat\n'), 'back squat');
    expect(normalizeExerciseName('Pull-Up'), 'pull-up');
    expect(normalizeExerciseName('   '), '');
  });

  test('an official exercise is found by its alias, as written or as a suggestion', () {
    const cat = [
      CatalogExercise(id: 'cj', name: 'Clean & Jerk', aliases: ['C&J'], isPredefined: true),
    ];
    final named = ok(
      workout(
        [
          {'sets': 1, 'reps': 1, 'percent': 90},
        ],
        {'name': 'c&j'},
      ),
      null,
      cat,
    );
    expect(firstExercise(named)['match'], {'exerciseId': 'cj', 'name': 'Clean & Jerk', 'confidence': 'exact'});

    final suggested = ok(
      workout(
        [
          {'sets': 1, 'reps': 1, 'percent': 90},
        ],
        {'name': 'CJ', 'match': 'C&J', 'confidence': 'high'},
      ),
      null,
      cat,
    );
    expect((firstExercise(suggested)['match'] as Json)['exerciseId'], 'cj');
  });

  test('one name: active official, then retired official, then the oldest custom', () {
    const custom = CatalogExercise(id: 'mine', name: 'C&J', createdAt: '2024-01-01');
    const retired = CatalogExercise(
      id: 'old',
      name: 'C&J Old',
      aliases: ['C&J'],
      isPredefined: true,
      retiredAt: '2026-01-01',
    );
    const active = CatalogExercise(id: 'cj', name: 'Clean & Jerk', aliases: ['C&J'], isPredefined: true);
    const newerCustom = CatalogExercise(id: 'mine2', name: 'c&j', createdAt: '2025-01-01');
    String? pick(List<CatalogExercise> cat) {
      final r = ok(
        workout(
          [
            {'sets': 1, 'reps': 1, 'percent': 90},
          ],
          {'name': 'C&J'},
        ),
        null,
        cat,
      );
      return (firstExercise(r)['match'] as Json?)?['exerciseId'] as String?;
    }

    expect(pick([custom, retired, active]), 'cj');
    expect(pick([custom, retired]), 'old');
    expect(pick([newerCustom, custom]), 'mine');
  });

  test("keeps the file's own description, unmarked", () {
    final r = ok({
      ...workout([
        {'sets': 3, 'reps': 5},
      ]),
      'description': '  Heavy day.\n\nKeep rest short.  ',
    });
    expect(r['description'], 'Heavy day.\n\nKeep rest short.');
    expect(r.containsKey('descriptionGenerated'), false);
  });

  test('marks a description the model wrote', () {
    final r = ok({
      ...workout([
        {'sets': 3, 'reps': 5},
      ]),
      'description': 'Squat day.',
      'descriptionGenerated': true,
    });
    expect(r['description'], 'Squat day.');
    expect(r['descriptionGenerated'], true);
  });

  test('a blank or missing description is left out, and so is its mark', () {
    final blank = ok({
      ...workout([
        {'sets': 3, 'reps': 5},
      ]),
      'description': '   ',
      'descriptionGenerated': true,
    });
    expect(blank.containsKey('description'), false);
    expect(blank.containsKey('descriptionGenerated'), false);
    expect(
      ok(
        workout([
          {'sets': 3, 'reps': 5},
        ]),
      ).containsKey('description'),
      false,
    );
  });

  test('a description alone is not training content', () {
    expect(normalizeImportResult({'type': 'none', 'description': 'A cat photo.'}, catalog), isA<NormalizeNoWorkout>());
  });

  // Dart only: JavaScript has one number type, Dart two.
  test('whole numbers are stored as ints, as JSON from JavaScript would be', () {
    final set = firstSet(
      ok(
        workout([
          {'sets': 3.0, 'reps': 5.0, 'percent': 70.0, 'percentMax': 72.5},
        ]),
      ),
    );
    expect(set, {'sets': 3, 'reps': 5, 'percent': 70, 'percentMax': 72.5});
    expect(set['percent'], isA<int>());
    expect(set['sets'], isA<int>());
  });
}
