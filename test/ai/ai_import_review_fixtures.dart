/// Stored results in the shape `normalize.ts` writes.
library;

Map<String, dynamic> match(String id, String name, [String confidence = 'exact']) => {
  'exerciseId': id,
  'name': name,
  'confidence': confidence,
};

/// A handwritten workout with one of everything the review handles: a
/// percentage with a basis lift, a weight with no unit, a printed lb weight,
/// an open set with no prescribed load, an unmatched name used twice, a
/// low-confidence guess, an unreadable value and content that couldn't be
/// structured.
Map<String, dynamic> workoutResult() => {
  'schemaVersion': 1,
  'type': 'workout',
  'title': 'Lower body A',
  'weeks': [
    {
      'days': [
        {
          'title': 'Lower body A',
          'isRestDay': false,
          'exercises': [
            {
              'name': 'Front Squat',
              'match': match('ex-fs', 'Front Squat'),
              'sets': [
                {
                  'sets': 3,
                  'reps': 3,
                  'percent': 70,
                  'percentMax': 72.5,
                  'basisExercise': {'name': '2 Hang Clean + 1 Jerk', 'match': null},
                },
              ],
            },
            {
              'name': 'Romanian Deadlift',
              'match': match('ex-rdl', 'Romanian Deadlift'),
              'sets': [
                {'sets': 3, 'reps': 8, 'weight': 100},
                {'sets': 2, 'reps': 10, 'openLoad': true, 'note': 'light by feel'},
              ],
            },
            {
              'name': 'Bench',
              'match': match('ex-bench', 'Bench Press', 'low'),
              'sets': [
                {'sets': 4, 'reps': 6, 'weight': 225, 'unit': 'lb', 'rpeMin': 7, 'rpeMax': 8},
              ],
            },
            {
              'name': '2 Hang Clean + 1 Jerk',
              'match': null,
              'notes': 'Combination: 2 hang cleans then 1 jerk',
              'sets': [
                {
                  'sets': 5,
                  'percent': 75,
                  'unreadable': ['reps'],
                  'note': 'Reps as printed: 2+l',
                },
              ],
            },
          ],
        },
      ],
    },
  ],
  'unstructured': [
    {'location': 'Workout, Day 1, Lower body A, Walking Lunge', 'originalText': 'Walking lunge 3 x 12 light by feel'},
  ],
  'flags': {
    'handwritten': true,
    'needsUnit': true,
    'uncertainExercises': true,
    'unreadableValues': true,
    'unstructuredContent': true,
  },
};

Map<String, dynamic> _day(String weekday, List<Map<String, dynamic>> exercises) => {
  'weekday': weekday,
  'isRestDay': false,
  'exercises': exercises,
};

Map<String, dynamic> _pauseSquat(double percent) => {
  'name': 'Pause squat',
  'match': null,
  'sets': [
    {'sets': 3, 'reps': 2, 'percent': percent},
  ],
};

/// A printed program of [weeks] weeks: a squat day on Monday, rest on
/// Tuesday, with the unmatched "Pause squat" in every week.
Map<String, dynamic> programResult({int weeks = 2}) => {
  'schemaVersion': 1,
  'type': 'program',
  'title': 'Squat cycle',
  'weeks': [
    for (var w = 0; w < weeks; w++)
      {
        'label': 'Week ${w + 1}',
        'days': [
          _day('monday', [
            {
              'name': 'Back Squat',
              'match': match('ex-bs', 'Back Squat'),
              'sets': [
                {'sets': 5, 'reps': 5, 'percent': 70 + w},
              ],
            },
            _pauseSquat(60.0 + w),
          ]),
          {'weekday': 'tuesday', 'isRestDay': true, 'exercises': <Map<String, dynamic>>[]},
        ],
      },
  ],
  'unstructured': <Map<String, dynamic>>[],
  'flags': {
    'handwritten': false,
    'needsUnit': false,
    'uncertainExercises': true,
    'unreadableValues': false,
    'unstructuredContent': false,
  },
};
