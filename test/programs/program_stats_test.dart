import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/programs/models/program_instance.dart';
import 'package:nomorex/features/programs/utils/program_stats.dart';

StatsDay _d(String id, int pos, {bool rest = false}) =>
    StatsDay(id: id, position: pos, isRest: rest);

void main() {
  final weeks = [
    StatsWeek([_d('a', 0), _d('b', 1), _d('c', 2, rest: true)]),
    StatsWeek([_d('d', 3), _d('e', 4, rest: true)]),
    StatsWeek([_d('f', 5, rest: true), _d('g', 6, rest: true)]),
  ];

  test('template totals count rest days as days but not as workouts', () {
    final s = templateStats(weeks);
    expect((s.weeks, s.days, s.workouts), (3, 7, 3));
    expect(s.isRun, isFalse);
  });

  group('runStats', () {
    final start = DateTime(2026, 8, 1);

    ProgramStats stats(
      Map<String, String> status, {
      required DateTime asOf,
      bool ended = false,
    }) =>
        runStats(weeks,
            workoutStatusByDayId: status, startedAt: start, asOf: asOf, ended: ended);

    test('counts only finished workouts', () {
      final s = stats({'a': 'finished', 'b': 'in_progress', 'd': 'not_started'},
          asOf: DateTime(2026, 8, 1));
      expect(s.completedWorkouts, 1);
    });

    test('a week completes when all its training workouts are finished', () {
      expect(
        stats({'a': 'finished'}, asOf: DateTime(2026, 8, 1)).completedWeeks,
        0,
      );
      expect(
        stats({'a': 'finished', 'b': 'finished'}, asOf: DateTime(2026, 8, 1))
            .completedWeeks,
        1,
      );
    });

    test('a week of only rest days completes once its dates have passed', () {
      final s = stats({}, asOf: DateTime(2026, 8, 8)); // day after position 6
      expect(s.completedWeeks, 1);
      expect(stats({}, asOf: DateTime(2026, 8, 7)).completedWeeks, 0);
    });

    test('days complete once their calendar date has passed (not today)', () {
      expect(stats({}, asOf: DateTime(2026, 8, 1)).completedDays, 0);
      expect(stats({}, asOf: DateTime(2026, 8, 2)).completedDays, 1);
      expect(stats({}, asOf: DateTime(2026, 8, 20)).completedDays, 7);
    });

    test('an ended run counts the day it ended on', () {
      expect(stats({}, asOf: DateTime(2026, 8, 3), ended: true).completedDays, 3);
      expect(stats({}, asOf: DateTime(2026, 8, 3)).completedDays, 2);
    });
  });

  group('check marks', () {
    final clock = RunClock(startedAt: DateTime(2026, 8, 1), asOf: DateTime(2026, 8, 3));
    final status = {'a': 'finished', 'b': 'in_progress'};

    test('a training day is checked only once its workout is finished', () {
      expect(isDayChecked(_d('a', 0), workoutStatusByDayId: status, clock: clock), isTrue);
      expect(isDayChecked(_d('b', 1), workoutStatusByDayId: status, clock: clock), isFalse);
    });

    test('a rest day is checked once its date has passed', () {
      expect(isDayChecked(_d('c', 1, rest: true), workoutStatusByDayId: {}, clock: clock), isTrue);
      expect(isDayChecked(_d('c', 2, rest: true), workoutStatusByDayId: {}, clock: clock), isFalse);
    });

    test('week check agrees with the completed-weeks count', () {
      final statuses = {'a': 'finished', 'b': 'finished', 'd': 'finished'};
      final done = [
        for (final w in weeks)
          isWeekDone(w, workoutStatusByDayId: statuses, clock: clock),
      ];
      final s = runStats(weeks,
          workoutStatusByDayId: statuses,
          startedAt: DateTime(2026, 8, 1),
          asOf: DateTime(2026, 8, 3));
      expect(done.where((d) => d).length, s.completedWeeks);
      expect(done, [true, true, false]);
    });

    test('an empty week is never done', () {
      expect(
        isWeekDone(const StatsWeek([]), workoutStatusByDayId: {}, clock: clock),
        isFalse,
      );
    });
  });

  group('ProgramInstance.fromJson', () {
    final base = {
      'id': 'i1',
      'program_id': 'p1',
      'user_id': 'u1',
      'started_at': '2020-01-01',
      'status': 'active',
    };

    test('has no stats without the embedded structure', () {
      expect(ProgramInstance.fromJson(base).stats, isNull);
    });

    test('builds stats from embedded weeks and workouts', () {
      final i = ProgramInstance.fromJson({
        ...base,
        'programs': {
          'name': 'Block',
          'program_weeks': [
            {
              'id': 'w1',
              'position': 0,
              'program_days': [
                {'id': 'd1', 'position': 0, 'is_rest_day': false},
                {'id': 'd2', 'position': 1, 'is_rest_day': true},
              ],
            },
          ],
        },
        'workouts': [
          {'id': 'x', 'program_day_id': 'd1', 'status': 'finished'},
          {'id': 'y', 'program_day_id': null, 'status': 'finished'},
        ],
      });
      final s = i.stats!;
      expect((s.weeks, s.days, s.workouts), (1, 2, 1));
      expect((s.completedWeeks, s.completedDays, s.completedWorkouts), (1, 2, 1));
    });
  });
}
