import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart';
import 'package:nomorex/features/ai/core/ai_task.dart';
import 'package:nomorex/features/ai/core/genkit_provider.dart';
import 'package:nomorex/features/ai/core/model_router_provider.dart';
import 'package:nomorex/features/ai/utils/suggest_text.dart';
import 'package:nomorex/features/profile/providers/profile_provider.dart';
import 'package:nomorex/features/programs/models/program.dart';
import 'package:nomorex/features/programs/models/program_day.dart';
import 'package:nomorex/features/programs/models/program_exercise.dart';
import 'package:nomorex/features/programs/models/program_set.dart';
import 'package:nomorex/features/programs/models/program_week.dart';
import 'package:nomorex/features/programs/providers/program_detail_provider.dart';
import 'package:nomorex/features/programs/screens/program_edit_screen.dart';
import 'package:nomorex/features/workouts/models/workout.dart';
import 'package:nomorex/features/workouts/models/workout_exercise.dart';
import 'package:nomorex/features/workouts/models/workout_set.dart';
import 'package:nomorex/features/workouts/providers/workout_detail_provider.dart';
import 'package:nomorex/features/workouts/screens/edit_workout_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/program_fixtures.dart';
import 'core/ai_fakes.dart';

/// Records the saves the editor makes instead of writing to Supabase.
class _Detail extends WorkoutDetailNotifier {
  _Detail(this.workout, this.saved);
  final Workout workout;
  final List<String> saved;

  @override
  Future<Workout> build(String workoutId) async => workout;

  @override
  Future<void> updateTitle(String title) async => saved.add('title:$title');

  @override
  Future<void> updateDescription(String? description) async => saved.add('description:$description');
}

class _Program extends ProgramDetailNotifier {
  _Program(this.program, this.saved);
  final Program program;
  final List<String> saved;

  @override
  Future<Program> build(String programId) async => program;

  @override
  Future<void> updateProgramMeta({String? name, String? description}) async =>
      saved.add(name != null ? 'name:$name' : 'description:$description');
}

WorkoutSet _set(String id, {int reps = 3, double? pct, double? kg}) => WorkoutSet(
  id: id,
  workoutExerciseId: 'we',
  position: 0,
  weightMode: pct != null ? 'percentage' : 'absolute',
  targetReps: reps,
  percentage: pct,
  absoluteWeightKg: kg,
);

Workout _workout({bool withExercises = true}) => Workout(
  id: 'w1',
  userId: 'u1',
  title: 'Day 1',
  date: DateTime(2026, 11, 27),
  updatedAt: DateTime(2026, 11, 27),
  workoutGroupId: 'g1',
  exercises: [
    if (withExercises) ...[
      WorkoutExercise(
        id: 'we1',
        workoutId: 'w1',
        exerciseId: 'e1',
        exerciseName: 'Front Squat',
        position: 0,
        sets: [for (var i = 0; i < 5; i++) _set('a$i', pct: 75)],
      ),
      WorkoutExercise(
        id: 'we2',
        workoutId: 'w1',
        exerciseId: 'e2',
        exerciseName: 'Romanian Deadlift',
        position: 1,
        sets: [for (var i = 0; i < 3; i++) _set('b$i', reps: 8, kg: 80)],
      ),
    ],
  ],
);

/// [weeks] weeks of four days, each with Snatch and Back Squat.
Program _program(int weeks) => Program(
  id: 'p1',
  userId: 'u1',
  name: 'Block',
  createdAt: DateTime(2026, 11, 1),
  updatedAt: DateTime(2026, 11, 1),
  weeks: [
    for (var w = 0; w < weeks; w++)
      ProgramWeek(
        id: 'w$w',
        programId: 'p1',
        weekNumber: w + 1,
        position: w,
        days: [
          for (var d = 0; d < 4; d++)
            ProgramDay(
              id: 'd$w-$d',
              programWeekId: 'w$w',
              dayNumber: d + 1,
              title: 'Day ${d + 1}',
              position: w * 4 + d,
              sessions: soloSession('d$w-$d', [
                for (final (i, name) in ['Snatch', 'Back Squat'].indexed)
                  ProgramExercise(
                    id: 'pe$w-$d-$i',
                    programDayId: 'd$w-$d',
                    exerciseId: 'x$i',
                    exerciseName: name,
                    position: i,
                    sets: [
                      for (var s = 0; s < 4; s++)
                        ProgramSet(
                          id: 's$w-$d-$i-$s',
                          programExerciseId: 'pe$w-$d-$i',
                          position: s,
                          weightMode: 'percentage',
                          targetReps: 2,
                          percentage: 70.0 + w * 2,
                        ),
                    ],
                  ),
              ]),
            ),
        ],
      ),
  ],
);

const _ready = OnDeviceStatus(OnDeviceAvailability.ready, modelName: 'fake/model');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('cleaning a suggestion', () {
    test('drops quotes and a title\'s full stop', () {
      expect(cleanSuggestion(' "Heavy Pulls and Squats." ', SuggestField.title), 'Heavy Pulls and Squats');
      expect(cleanSuggestion('Squats.', SuggestField.description), 'Squats.');
    });

    test('cuts a long one at a word', () {
      final cut = cleanSuggestion('Front Squat and Romanian Deadlift Strength Builder Day', SuggestField.title)!;
      expect(cut.length, lessThanOrEqualTo(SuggestField.title.maxLength));
      expect(cut, 'Front Squat and Romanian Deadlift');
    });

    test('nothing left is null', () => expect(cleanSuggestion(' "" ', SuggestField.title), isNull));
  });

  group('outlines', () {
    test('a workout is one line per exercise, as the editor summarizes it', () {
      expect(workoutOutline(_workout(), 'kg'), 'Front Squat: 5 × 3 · 75%\nRomanian Deadlift: 3 × 8 · 80 kg');
      expect(workoutHasOutline(_workout(withExercises: false)), isFalse);
    });

    test('a program gives its shape and exercises, and stays short however long it is', () {
      final outline = programOutline(_program(40), 'kg');
      expect(outline, startsWith('40 weeks, about 4 training days a week.'));
      expect(outline, contains('Snatch (160), Back Squat (160)'));
      expect(outline, contains('Week 1\n  Day 1: Snatch 4 × 2 · 70%; Back Squat 4 × 2 · 70%'));
      expect(outline.length, lessThanOrEqualTo(kSuggestOutlineMaxChars));
      expect(outline, isNot(contains('Week 40')));
    });
  });

  group('the workout editor', () {
    Future<List<String>> pumpEditor(
      WidgetTester tester, {
      OnDeviceStatus? onDevice = _ready,
      Workout? workout,
      String reply = '{"title":"Squat and Hinge"}',
      List<ModelRequest>? requests,
    }) async {
      final saved = <String>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...aiDeviceOverrides(),
            workoutDetailProvider('w1').overrideWith(() => _Detail(workout ?? _workout(), saved)),
            unitPreferenceProvider.overrideWithValue('kg'),
            onDeviceAvailabilityProvider.overrideWithValue(onDevice),
            genkitProvider.overrideWith(
              (ref) async => fakeGenkit((req, _) async {
                requests?.add(req);
                return textResponse(reply);
              }),
            ),
          ],
          child: const MaterialApp(home: EditWorkoutScreen(workoutId: 'w1')),
        ),
      );
      await tester.pumpAndSettle();
      return saved;
    }

    testWidgets('fills the title from the exercises, saves it, and Undo puts the old one back', (tester) async {
      final requests = <ModelRequest>[];
      final saved = await pumpEditor(tester, requests: requests);

      await tester.tap(find.byKey(const Key('suggest_title')));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'Squat and Hinge'), findsOneWidget);
      expect(saved, ['title:Squat and Hinge']);
      expect(find.text('Title suggested from your exercises'), findsOneWidget);
      final prompt = requests.single.messages.expand((m) => m.content).map((p) => p.text ?? '').join('\n');
      expect(prompt, contains('Front Squat: 5 × 3 · 75%'));

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Day 1'), findsOneWidget);
      expect(saved.last, 'title:Day 1');
    });

    testWidgets('suggests a description too', (tester) async {
      final saved = await pumpEditor(tester, reply: '{"description":"Squats, then hinges."}');
      await tester.tap(find.byKey(const Key('suggest_description')));
      await tester.pumpAndSettle();
      expect(saved, ['description:Squats, then hinges.']);
    });

    testWidgets('a failed run says so and leaves the field alone', (tester) async {
      final saved = await pumpEditor(tester, reply: 'not json at all');
      await tester.tap(find.byKey(const Key('suggest_title')));
      await tester.pumpAndSettle();
      expect(saved, isEmpty);
      expect(find.widgetWithText(TextFormField, 'Day 1'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
    });

    testWidgets('hidden without an on-device model', (tester) async {
      await pumpEditor(tester, onDevice: const OnDeviceStatus(OnDeviceAvailability.downloadable));
      expect(find.byKey(const Key('suggest_title')), findsNothing);
      expect(find.byKey(const Key('suggest_description')), findsNothing);
    });

    testWidgets('hidden while there are no exercises to suggest from', (tester) async {
      await pumpEditor(tester, workout: _workout(withExercises: false));
      expect(find.byKey(const Key('suggest_title')), findsNothing);
    });
  });

  testWidgets('the program editor suggests a description from the weeks', (tester) async {
    final saved = <String>[];
    final requests = <ModelRequest>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...aiDeviceOverrides(),
          programDetailProvider('p1').overrideWith(() => _Program(_program(2), saved)),
          unitPreferenceProvider.overrideWithValue('kg'),
          onDeviceAvailabilityProvider.overrideWithValue(_ready),
          genkitProvider.overrideWith(
            (ref) async => fakeGenkit((req, _) async {
              requests.add(req);
              return textResponse('{"description":"Two weeks of snatches and squats."}');
            }),
          ),
        ],
        child: const MaterialApp(home: ProgramEditScreen(programId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Suggest a name'), findsOneWidget);
    await tester.tap(find.byTooltip('Suggest a description'));
    await tester.pumpAndSettle();

    expect(saved, ['description:Two weeks of snatches and squats.']);
    expect(find.text('Description suggested from your weeks'), findsOneWidget);
    final prompt = requests.single.messages.expand((m) => m.content).map((p) => p.text ?? '').join('\n');
    expect(prompt, contains('2 weeks, about 4 training days a week.'));
  });
}
