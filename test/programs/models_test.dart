import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/programs/models/program.dart';
import 'package:nomorex/features/programs/models/program_instance.dart';
import 'package:nomorex/features/programs/models/program_set.dart';

void main() {
  test(
    'Program.fromJson parses nested weeks/days/exercises/sets, sorted by position',
    () {
      final json = {
        'id': 'p1',
        'user_id': 'u1',
        'name': 'ZT 6 Week Program',
        'description': 'A strength program',
        'is_public': false,
        'is_archived': false,
        'archived_at': null,
        'created_at': '2026-06-01T00:00:00Z',
        'updated_at': '2026-06-02T00:00:00Z',
        'program_weeks': [
          {
            'id': 'w2',
            'program_id': 'p1',
            'week_number': 2,
            'label': 'Loading Week 2',
            'notes': null,
            'position': 1,
            'program_days': [],
          },
          {
            'id': 'w1',
            'program_id': 'p1',
            'week_number': 1,
            'label': 'Loading Week 1',
            'notes': null,
            'position': 0,
            'program_days': [
              {
                'id': 'd1',
                'program_week_id': 'w1',
                'day_number': 1,
                'title': 'Day 1',
                'is_rest_day': false,
                'notes': null,
                'position': 0,
                'program_sessions': [
                  {
                    'id': 's2',
                    'program_day_id': 'd1',
                    'title': 'PM',
                    'notes': null,
                    'position': 1,
                    'program_exercises': [
                      {
                        'id': 'pe2',
                        'program_day_id': 'd1',
                        'program_session_id': 's2',
                        'exercise_id': 'e2',
                        'position': 0,
                        'notes': null,
                        'exercises': {'name': 'Front Squat'},
                        'program_sets': [],
                      },
                    ],
                  },
                  {
                    'id': 's1',
                    'program_day_id': 'd1',
                    'title': null,
                    'notes': 'fasted',
                    'position': 0,
                'program_exercises': [
                  {
                    'id': 'pe1',
                    'program_session_id': 's1',
                    'program_day_id': 'd1',
                    'exercise_id': 'e1',
                    'position': 0,
                    'notes': 'build to a heavy triple',
                    'exercises': {'name': 'Snatch'},
                    'program_sets': [
                      {
                        'id': 'ps1',
                        'program_exercise_id': 'pe1',
                        'position': 0,
                        'target_reps': 3,
                        'weight_mode': 'percentage',
                        'percentage': 80,
                        'absolute_weight_kg': null,
                        'basis_exercise_id': null,
                        'note': null,
                      },
                    ],
                  },
                ],
                  },
                ],
              },
            ],
          },
        ],
      };

      final program = Program.fromJson(json);
      expect(program.name, 'ZT 6 Week Program');
      expect(program.weeks.map((w) => w.weekNumber), [1, 2]);
      final week1 = program.weeks.first;
      expect(week1.days.single.title, 'Day 1');
      final day1 = week1.days.single;
      expect(day1.sessions.map((s) => s.id), ['s1', 's2'], reason: 'sessions sorted by position');
      expect(day1.sessions.map((s) => s.label(day1.sessions.indexOf(s))), ['Session 1', 'PM']);
      expect(day1.sessions.first.notes, 'fasted');
      expect(day1.hasMultipleSessions, isTrue);
      expect(day1.canAddSession, isTrue);
      expect(day1.workoutKeys, ['s1', 's2']);
      expect(day1.exercises.map((e) => e.exerciseName), ['Snatch', 'Front Squat'],
          reason: 'exercises flatten session by session');
      expect(day1.exercises.first.programSessionId, 's1');
      final set1 = day1.exercises.first.sets.single;
      expect(set1.weightMode, 'percentage');
      expect(set1.percentage, 80);
    },
  );

  test('Program.fromJson tolerates missing nested collections', () {
    final program = Program.fromJson({
      'id': 'p1',
      'user_id': 'u1',
      'name': 'Empty program',
      'created_at': '2026-06-01T00:00:00Z',
      'updated_at': '2026-06-01T00:00:00Z',
    });
    expect(program.weeks, isEmpty);
    expect(program.isPublic, isFalse);
    expect(program.isArchived, isFalse);
    expect(program.archivedAt, isNull);
  });

  test('Program.fromJson parses is_archived and archived_at', () {
    final program = Program.fromJson({
      'id': 'p1',
      'user_id': 'u1',
      'name': 'Archived program',
      'is_archived': true,
      'archived_at': '2026-07-01T00:00:00Z',
      'created_at': '2026-06-01T00:00:00Z',
      'updated_at': '2026-07-01T00:00:00Z',
    });
    expect(program.isArchived, isTrue);
    expect(program.archivedAt, DateTime.parse('2026-07-01T00:00:00Z'));
  });

  test('ProgramSet.fromJson parses basis_exercise_id and its joined name', () {
    final set = ProgramSet.fromJson({
      'id': 'ps1',
      'program_exercise_id': 'pe1',
      'position': 0,
      'weight_mode': 'percentage',
      'percentage': 85,
      'basis_exercise_id': 'e2',
      'exercises': {'name': 'Clean and Jerk'},
    });
    expect(set.basisExerciseId, 'e2');
    expect(set.basisExerciseName, 'Clean and Jerk');
  });

  test('ProgramSet.fromJson tolerates a missing basis_exercise_id/join', () {
    final set = ProgramSet.fromJson({
      'id': 'ps1',
      'program_exercise_id': 'pe1',
      'position': 0,
      'weight_mode': 'absolute',
      'absolute_weight_kg': 60,
    });
    expect(set.basisExerciseId, isNull);
    expect(set.basisExerciseName, isNull);
  });

  test('ProgramInstance.fromJson parses the joined program name', () {
    final instance = ProgramInstance.fromJson({
      'id': 'pi1',
      'program_id': 'p1',
      'user_id': 'u1',
      'started_at': '2026-06-01',
      'status': 'active',
      'programs': {'name': 'ZT 6 Week Program'},
    });
    expect(instance.programName, 'ZT 6 Week Program');
    expect(instance.status, 'active');
    expect(instance.startedAt, DateTime.parse('2026-06-01'));
  });

  test('ProgramInstance.fromJson tolerates a missing joined program name', () {
    final instance = ProgramInstance.fromJson({
      'id': 'pi1',
      'program_id': 'p1',
      'user_id': 'u1',
      'started_at': '2026-06-01',
      'status': 'completed',
    });
    expect(instance.programName, isNull);
  });

  test('Program.fromJson parses copy attribution and defaults to not a copy', () {
    Map<String, dynamic> base() => {
          'id': 'p1',
          'user_id': 'u1',
          'name': 'Block',
          'created_at': '2026-10-12T00:00:00Z',
          'updated_at': '2026-10-12T00:00:00Z',
        };
    final copy = Program.fromJson({
      ...base(),
      'is_copy': true,
      'copied_from_user_id': 'u2',
      'copied_from_display_name': 'BeastModeB',
      'copied_from_program_id': 'p0',
    });
    expect(copy.isCopy, isTrue);
    expect(copy.copiedFromUserId, 'u2');
    expect(copy.copiedFromDisplayName, 'BeastModeB');
    expect(copy.copiedFromProgramId, 'p0');

    final own = Program.fromJson(base());
    expect(own.isCopy, isFalse);
    expect(own.copiedFromProgramId, isNull);
  });

  group('day offsets: every week is 7 calendar days', () {
    Map<String, dynamic> day(String id, int position) =>
        {'id': id, 'program_week_id': 'w', 'day_number': 1, 'title': id, 'position': position};
    Map<String, dynamic> week(String id, int number, int position, List<Map<String, dynamic>> days) =>
        {'id': id, 'program_id': 'p', 'week_number': number, 'position': position, 'program_days': days};

    // Out of order, with gaps in the day positions; Week 2 is empty.
    final json = {
      'id': 'p',
      'user_id': 'u',
      'name': 'Short weeks',
      'created_at': '2026-11-01T00:00:00Z',
      'updated_at': '2026-11-01T00:00:00Z',
      'program_weeks': [
        week('w3', 3, 2, [day('c', 40)]),
        week('w1', 1, 0, [day('b', 9), day('a', 2), day('a2', 5)]),
        week('w2', 2, 1, []),
      ],
    };

    test('Program.fromJson dates a day by its week and place in the week', () {
      final program = Program.fromJson(json);
      expect(program.weeks.map((w) => w.id), ['w1', 'w2', 'w3']);
      expect(
        {for (final w in program.weeks) for (final d in w.days) d.id: d.dayOffset},
        {'a': 0, 'a2': 1, 'b': 2, 'c': 14},
      );
      expect(program.lastDayOffset, 14);
      expect(program.weeks.first.isFull, isFalse);
    });

    test('a program with no days has no last day', () {
      expect(Program.fromJson({...json, 'program_weeks': [week('w1', 1, 0, [])]}).lastDayOffset, isNull);
    });

    test('ProgramInstance.fromJson gives its structure the same offsets', () {
      final instance = ProgramInstance.fromJson({
        'id': 'i',
        'program_id': 'p',
        'user_id': 'u',
        'started_at': '2026-11-16',
        'status': 'active',
        'programs': {'name': 'Short weeks', 'program_weeks': json['program_weeks']},
      });
      expect(
        [for (final w in instance.structure!) [for (final d in w.days) d.dayOffset]],
        [[0, 1, 2], <int>[], [14]],
      );
    });
  });
}
