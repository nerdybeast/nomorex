import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/programs/models/program.dart';
import 'package:nomorex/features/programs/models/program_instance.dart';
import 'package:nomorex/features/programs/models/program_set.dart';

void main() {
  test('Program.fromJson parses nested weeks/days/exercises/sets, sorted by position', () {
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
              'program_exercises': [
                {
                  'id': 'pe1',
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
    };

    final program = Program.fromJson(json);
    expect(program.name, 'ZT 6 Week Program');
    expect(program.weeks.map((w) => w.weekNumber), [1, 2]);
    final week1 = program.weeks.first;
    expect(week1.days.single.title, 'Day 1');
    final day1 = week1.days.single;
    expect(day1.exercises.single.exerciseName, 'Snatch');
    final set1 = day1.exercises.single.sets.single;
    expect(set1.weightMode, 'percentage');
    expect(set1.percentage, 80);
  });

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
}
