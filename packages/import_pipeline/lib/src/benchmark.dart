import 'exercise_name.dart';
import 'normalize.dart';

/// One prescription row, as a benchmark answer key writes it (see
/// `benchmark/README.md`).
class BenchRow {
  const BenchRow({required this.name, required this.sets, required this.reps, required this.load, this.notes = ''});

  factory BenchRow.fromJson(Map<String, dynamic> json) => BenchRow(
    name: json['name'] as String,
    sets: (json['sets'] as num?)?.toInt() ?? 1,
    reps: '${json['reps'] ?? ''}',
    load: '${json['load'] ?? ''}',
  );

  final String name;
  final int sets;
  final String reps;
  final String load;

  /// The set's and exercise's notes, where a result keeps what has no field.
  final String notes;

  /// Whether this result row reads the same as [expected], an answer-key row.
  bool sameAs(BenchRow expected) =>
      normalizeExerciseName(name) == normalizeExerciseName(expected.name) &&
      sets == expected.sets &&
      (reps == expected.reps || _repsInNotes(expected.reps)) &&
      load.replaceAll(' ', '').toLowerCase() == expected.load.replaceAll(' ', '').toLowerCase();

  /// A time or distance ("45s", "40m") has no field in the import format, so
  /// a correct result keeps it in a note ("45s hold", "45 seconds").
  bool _repsInNotes(String expectedReps) {
    final m = RegExp(r'^(\d+)\s*([a-z]+)$', caseSensitive: false).firstMatch(expectedReps.trim());
    if (reps.isNotEmpty || m == null) return false;
    return RegExp('(^|[^0-9])${m[1]}\\s*${m[2]![0]}', caseSensitive: false).hasMatch(notes);
  }

  @override
  String toString() =>
      '$name $sets x $reps ${load.isEmpty ? '(no load)' : load}${notes.isEmpty ? '' : ' [notes: $notes]'}';
}

/// An answer key: training days in order, each its rows in order.
List<List<BenchRow>> readAnswerKey(Map<String, dynamic> json) => [
  for (final day in (json['days'] as List).cast<Map<String, dynamic>>())
    [for (final row in (day['exercises'] as List).cast<Map<String, dynamic>>()) BenchRow.fromJson(row)],
];

final _printedReps = RegExp(r'Reps as printed: ([^.]+)');

String _num(Object? n) => switch (n) {
  final double d when d == d.truncateToDouble() => '${d.toInt()}',
  final Object v => '$v',
  null => '',
};

/// A normalized import result as answer-key rows: its training days in order,
/// each exercise's sets in order.
List<List<BenchRow>> resultRows(Json result) => [
  for (final week in (result['weeks'] as List).cast<Json>())
    for (final day in (week['days'] as List).cast<Json>())
      if (dayExercises(day).isNotEmpty)
        [
          for (final exercise in dayExercises(day))
            for (final set in (exercise['sets'] as List).cast<Json>())
              BenchRow(
                name: exercise['name'] as String,
                notes: [set['note'], exercise['notes']].whereType<String>().join(' · '),
                sets: (set['sets'] as num?)?.toInt() ?? 1,
                // A time or distance ("45s", "40m") isn't a rep count, so the
                // pipeline keeps it in the note, where the review shows it.
                reps: set['reps'] == null
                    ? (_printedReps.firstMatch('${set['note'] ?? ''}')?.group(1) ?? '')
                    : set['repsMax'] == null
                    ? _num(set['reps'])
                    : '${_num(set['reps'])}-${_num(set['repsMax'])}',
                load: switch (set) {
                  {'percent': final p?} =>
                    set['percentMax'] == null ? '${_num(p)}%' : '${_num(p)}-${_num(set['percentMax'])}%',
                  {'weight': final w?} => '${_num(w)}${set['unit'] ?? ''}',
                  {'rpeMin': final r?} => set['rpeMax'] == null ? 'RPE ${_num(r)}' : 'RPE ${_num(r)}-${_num(set['rpeMax'])}',
                  _ => '',
                },
              ),
        ],
];

/// How a result compares with its answer key.
class BenchScore {
  BenchScore(this.expected, this.actual) {
    for (var d = 0; d < expected.length; d++) {
      final want = expected[d];
      final got = d < actual.length ? actual[d] : const <BenchRow>[];
      for (var i = 0; i < want.length; i++) {
        final row = i < got.length ? got[i] : null;
        if (row != null && row.sameAs(want[i])) {
          exact++;
        } else {
          misses.add('Day ${d + 1}, row ${i + 1}: expected ${want[i]}, got ${row ?? 'nothing'}');
        }
      }
      for (var i = want.length; i < got.length; i++) {
        misses.add('Day ${d + 1}, row ${i + 1}: unexpected ${got[i]}');
      }
    }
    for (var d = expected.length; d < actual.length; d++) {
      misses.add('Day ${d + 1}: an unexpected training day of ${actual[d].length} rows');
    }
  }

  final List<List<BenchRow>> expected;
  final List<List<BenchRow>> actual;
  var exact = 0;
  final misses = <String>[];

  int get total => expected.fold(0, (n, day) => n + day.length);
}
