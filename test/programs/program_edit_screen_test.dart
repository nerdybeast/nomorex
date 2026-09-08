import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/exercises/models/exercise.dart';
import 'package:nomorex/features/exercises/providers/exercises_provider.dart';
import 'package:nomorex/features/profile/providers/profile_provider.dart';
import 'package:nomorex/features/programs/models/program.dart';
import 'package:nomorex/features/programs/models/program_day.dart';
import 'package:nomorex/features/programs/models/program_exercise.dart';
import 'package:nomorex/features/programs/models/program_set.dart';
import 'package:nomorex/features/programs/models/program_week.dart';
import 'package:nomorex/features/programs/providers/program_detail_provider.dart';
import 'package:nomorex/features/programs/screens/program_edit_screen.dart';

class _StubExercisesNotifier extends ExercisesNotifier {
  @override
  Future<List<Exercise>> build() async =>
      const [Exercise(id: 'e1', name: 'Back Squat', isPredefined: true)];
}

class _TestProgramDetailNotifier extends ProgramDetailNotifier {
  _TestProgramDetailNotifier(
    this._program, {
    this.onAddWeek,
    this.onAddExercise,
    this.onRemoveWeek,
    this.onReorderExercises,
    this.onReorderSets,
  });
  final Program _program;
  final VoidCallback? onAddWeek;
  final void Function(String dayId, String exerciseId)? onAddExercise;
  final void Function(String weekId)? onRemoveWeek;
  final void Function(String dayId, List<String> orderedExerciseIds)? onReorderExercises;
  final void Function(String programExerciseId, List<String> orderedSetIds)? onReorderSets;

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

  @override
  Future<void> removeWeek(String weekId) async {
    onRemoveWeek?.call(weekId);
  }

  @override
  Future<void> reorderExercises({
    required String dayId,
    required List<String> orderedExerciseIds,
  }) async {
    onReorderExercises?.call(dayId, orderedExerciseIds);
  }

  @override
  Future<void> reorderSets(String programExerciseId, List<String> orderedSetIds) async {
    onReorderSets?.call(programExerciseId, orderedSetIds);
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

    await tester.ensureVisible(find.text('Exercise'));
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

  testWidgets('deleting an empty week removes it without a confirmation dialog', (tester) async {
    String? removedWeekId;
    final program = Program(
      id: 'p1',
      userId: 'u1',
      name: 'Test Program',
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
      weeks: [
        ProgramWeek(id: 'w1', programId: 'p1', weekNumber: 1, position: 0, days: const []),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          programDetailProvider('p1').overrideWith(
            () => _TestProgramDetailNotifier(
              program,
              onRemoveWeek: (weekId) => removedWeekId = weekId,
            ),
          ),
          unitPreferenceProvider.overrideWithValue('kg'),
        ],
        child: const MaterialApp(home: ProgramEditScreen(programId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(removedWeekId, 'w1');
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('deleting a week with days shows a confirmation dialog', (tester) async {
    String? removedWeekId;
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
          programDetailProvider('p1').overrideWith(
            () => _TestProgramDetailNotifier(
              program,
              onRemoveWeek: (weekId) => removedWeekId = weekId,
            ),
          ),
          unitPreferenceProvider.overrideWithValue('kg'),
        ],
        child: const MaterialApp(home: ProgramEditScreen(programId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    // Tap delete -> dialog appears; Cancel -> no delete.
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('This will also delete its 1 day.'), findsOneWidget);

    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Cancel'),
    ));
    await tester.pumpAndSettle();
    expect(removedWeekId, isNull);
    expect(find.byType(AlertDialog), findsNothing);

    // Tap delete -> dialog appears again; Delete -> removeWeek called.
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Delete'),
    ));
    await tester.pumpAndSettle();

    expect(removedWeekId, 'w1');
  });

  testWidgets('dragging an exercise within a day calls reorderExercises with the day id '
      'and new order', (tester) async {
    String? capturedDayId;
    List<String>? capturedOrder;
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
            ProgramDay(
              id: 'd1',
              programWeekId: 'w1',
              dayNumber: 1,
              title: 'Day 1',
              position: 0,
              exercises: const [
                ProgramExercise(
                  id: 'pe1',
                  programDayId: 'd1',
                  exerciseId: 'e1',
                  exerciseName: 'Back Squat',
                  position: 0,
                ),
                ProgramExercise(
                  id: 'pe2',
                  programDayId: 'd1',
                  exerciseId: 'e2',
                  exerciseName: 'Front Squat',
                  position: 1,
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          programDetailProvider('p1').overrideWith(
            () => _TestProgramDetailNotifier(
              program,
              onReorderExercises: (dayId, ids) {
                capturedDayId = dayId;
                capturedOrder = ids;
              },
            ),
          ),
          unitPreferenceProvider.overrideWithValue('kg'),
        ],
        child: const MaterialApp(home: ProgramEditScreen(programId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Week 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Day 1'));
    await tester.pumpAndSettle();

    final handles = find.byIcon(Icons.drag_handle);
    expect(handles, findsNWidgets(2));
    await tester.ensureVisible(handles.last);
    await tester.pumpAndSettle();

    final drag = await tester.startGesture(tester.getCenter(handles.first));
    await tester.pump(kPressTimeout);
    for (var i = 0; i < 10; i++) {
      await drag.moveBy(const Offset(0, 50));
      await tester.pump();
    }
    await drag.up();
    await tester.pumpAndSettle();

    expect(capturedDayId, 'd1');
    expect(capturedOrder, ['pe2', 'pe1']);
  });

  testWidgets('reordering sets within a program exercise calls reorderSets', (tester) async {
    String? capturedExerciseId;
    List<String>? capturedOrder;
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
            ProgramDay(
              id: 'd1',
              programWeekId: 'w1',
              dayNumber: 1,
              title: 'Day 1',
              position: 0,
              exercises: const [
                ProgramExercise(
                  id: 'pe1',
                  programDayId: 'd1',
                  exerciseId: 'e1',
                  exerciseName: 'Back Squat',
                  position: 0,
                  sets: [
                    ProgramSet(
                      id: 'set14',
                      programExerciseId: 'pe1',
                      position: 0,
                      weightMode: 'absolute',
                      targetReps: 14,
                      absoluteWeightKg: 50,
                    ),
                    ProgramSet(
                      id: 'set15',
                      programExerciseId: 'pe1',
                      position: 1,
                      weightMode: 'absolute',
                      targetReps: 15,
                      absoluteWeightKg: 45,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          programDetailProvider('p1').overrideWith(
            () => _TestProgramDetailNotifier(
              program,
              onReorderSets: (exerciseId, ids) {
                capturedExerciseId = exerciseId;
                capturedOrder = ids;
              },
            ),
          ),
          unitPreferenceProvider.overrideWithValue('kg'),
        ],
        child: const MaterialApp(home: ProgramEditScreen(programId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Week 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Day 1'));
    await tester.pumpAndSettle();

    final handles = find.byIcon(Icons.drag_handle);
    // One handle for the exercise card, one per set row.
    expect(handles, findsNWidgets(3));
    await tester.ensureVisible(handles.last);
    await tester.pumpAndSettle();

    final drag = await tester.startGesture(tester.getCenter(handles.at(1)));
    await tester.pump(kPressTimeout);
    for (var i = 0; i < 3; i++) {
      await drag.moveBy(const Offset(0, 50));
      await tester.pump();
    }
    await drag.up();
    await tester.pumpAndSettle();

    expect(capturedExerciseId, 'pe1');
    expect(capturedOrder, ['set15', 'set14']);
  });
}
