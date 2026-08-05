import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/exercises/models/exercise.dart';
import 'package:nomorex/features/exercises/providers/exercises_provider.dart';
import 'package:nomorex/features/profile/providers/profile_provider.dart';
import 'package:nomorex/features/programs/models/program.dart';
import 'package:nomorex/features/programs/models/program_day.dart';
import 'package:nomorex/features/programs/models/program_week.dart';
import 'package:nomorex/features/programs/providers/program_detail_provider.dart';
import 'package:nomorex/features/programs/screens/program_edit_screen.dart';

class _StubExercisesNotifier extends ExercisesNotifier {
  @override
  Future<List<Exercise>> build() async =>
      const [Exercise(id: 'e1', name: 'Back Squat', isPredefined: true)];
}

class _TestProgramDetailNotifier extends ProgramDetailNotifier {
  _TestProgramDetailNotifier(this._program, {this.onAddWeek, this.onAddExercise});
  final Program _program;
  final VoidCallback? onAddWeek;
  final void Function(String dayId, String exerciseId)? onAddExercise;

  @override
  Future<Program> build(String programId) async => _program;

  @override
  Future<void> addWeek({String? label, String? notes}) async {
    onAddWeek?.call();
  }

  @override
  Future<void> addExercise(String dayId, String exerciseId) async {
    onAddExercise?.call(dayId, exerciseId);
  }
}

void main() {
  testWidgets('tapping the Week FAB calls addWeek', (tester) async {
    var addWeekCalled = false;
    final program = Program(
      id: 'p1',
      userId: 'u1',
      name: 'Test Program',
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          programDetailProvider('p1').overrideWith(
            () => _TestProgramDetailNotifier(program, onAddWeek: () => addWeekCalled = true),
          ),
          unitPreferenceProvider.overrideWithValue('kg'),
        ],
        child: const MaterialApp(home: ProgramEditScreen(programId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(addWeekCalled, isTrue);
  });

  testWidgets('adding an exercise to a day calls addExercise with the day id', (tester) async {
    String? capturedDayId;
    String? capturedExerciseId;
    final program = Program(
      id: 'p1',
      userId: 'u1',
      name: 'Test Program',
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
      weeks: [
        ProgramWeek(
          id: 'w1',
          programId: 'p1',
          weekNumber: 1,
          position: 0,
          days: [
            ProgramDay(id: 'd1', programWeekId: 'w1', dayNumber: 1, title: 'Day 1', position: 0),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exercisesProvider.overrideWith(() => _StubExercisesNotifier()),
          programDetailProvider('p1').overrideWith(
            () => _TestProgramDetailNotifier(
              program,
              onAddExercise: (dayId, exerciseId) {
                capturedDayId = dayId;
                capturedExerciseId = exerciseId;
              },
            ),
          ),
          unitPreferenceProvider.overrideWithValue('kg'),
        ],
        child: const MaterialApp(home: ProgramEditScreen(programId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    // Expand Week 1, then Day 1.
    await tester.tap(find.text('Week 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Day 1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Exercise'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextFormField)),
      'Back',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Back Squat'));
    await tester.pumpAndSettle();

    expect(capturedDayId, 'd1');
    expect(capturedExerciseId, 'e1');
  });
}
