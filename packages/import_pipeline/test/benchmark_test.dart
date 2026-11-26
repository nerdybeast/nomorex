import 'dart:convert';
import 'dart:io';

import 'package:import_pipeline/import_pipeline.dart';
import 'package:import_pipeline/src/benchmark.dart';
import 'package:test/test.dart';

/// What a perfect read of [key] looks like to the model: the answer key's rows
/// as prescriptions.
Json perfectReply(Map<String, dynamic> key) => {
  'type': 'program',
  'weeks': [
    {
      'days': [
        for (final day in (key['days'] as List).cast<Map<String, dynamic>>())
          {
            'title': day['title'],
            'exercises': [
              for (final row in (day['exercises'] as List).cast<Map<String, dynamic>>())
                {
                  'name': row['name'],
                  'prescriptions': [
                    {
                      'sets': row['sets'],
                      'reps': row['reps'],
                      ...switch (row['load'] as String) {
                        final l when l.endsWith('%') => {'percent': l.substring(0, l.length - 1)},
                        final l when l.startsWith('RPE ') => {'rpeMin': l.substring(4)},
                        _ => {'note': 'by feel'},
                      },
                    },
                  ],
                },
            ],
          },
      ],
    },
  ],
};

void main() {
  final key = jsonDecode(File('benchmark/dense_page.expected.json').readAsStringSync()) as Map<String, dynamic>;
  final expected = readAnswerKey(key);

  test('the dense page key has 4 days and 32 rows', () {
    expect(expected.length, 4);
    expect(expected.fold<int>(0, (n, d) => n + d.length), 32);
  });

  test('a perfect read scores every row', () {
    final out = normalizeImportResult(perfectReply(key), const []) as NormalizeOk;
    final score = BenchScore(expected, resultRows(out.result));
    expect(score.misses, isEmpty);
    expect(score.exact, 32);
  });

  test('a wrong value and a missing row are named', () {
    final reply = perfectReply(key);
    final days = ((reply['weeks'] as List).first as Json)['days'] as List;
    final firstDay = (days.first as Json)['exercises'] as List;
    ((firstDay.first as Json)['prescriptions'] as List).first['reps'] = 3;
    firstDay.removeLast();
    final out = normalizeImportResult(reply, const []) as NormalizeOk;
    final score = BenchScore(expected, resultRows(out.result));
    expect(score.exact, 30);
    expect(score.misses.first, startsWith('Day 1, row 1: expected'));
    expect(score.misses.last, contains('got nothing'));
  });

  test('a time or distance kept in a note counts, a wrong one does not', () {
    const want = BenchRow(name: 'Plank', sets: 3, reps: '45s', load: '');
    expect(const BenchRow(name: 'Plank', sets: 3, reps: '', load: '', notes: '45s hold').sameAs(want), true);
    expect(const BenchRow(name: 'Plank', sets: 3, reps: '', load: '', notes: 'Hold 45 seconds').sameAs(want), true);
    expect(const BenchRow(name: 'Plank', sets: 3, reps: '', load: '', notes: '30s hold').sameAs(want), false);
    expect(const BenchRow(name: 'Plank', sets: 3, reps: '', load: '', notes: '145s').sameAs(want), false);
    expect(const BenchRow(name: 'Plank', sets: 3, reps: '', load: '').sameAs(want), false);
  });

  test('loads read as percent, weight with its unit, RPE, or nothing', () {
    final rows = resultRows({
      'weeks': [
        {
          'days': [
            {
              'sessions': [
                {
                  'exercises': [
                    {
                      'name': 'A',
                      'sets': [
                        {'sets': 3, 'reps': 5, 'percent': 67, 'percentMax': 72.5},
                        {'sets': 1, 'reps': 8, 'repsMax': 10, 'weight': 100, 'unit': 'kg'},
                        {'sets': 2, 'reps': 3, 'rpeMin': 7},
                        {'sets': 1, 'openLoad': true, 'note': 'max reps'},
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
    expect(rows.single.map((r) => '${r.sets}|${r.reps}|${r.load}'), ['3|5|67-72.5%', '1|8-10|100kg', '2|3|RPE 7', '1||']);
  });
}
