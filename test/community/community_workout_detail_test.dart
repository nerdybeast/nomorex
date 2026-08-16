import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nomorex/core/theme/dark_theme.dart';
import 'package:nomorex/core/utils/owner_name.dart';
import 'package:nomorex/features/community/providers/community_workout_detail_provider.dart';
import 'package:nomorex/features/community/screens/community_workout_detail_screen.dart';
import 'package:nomorex/features/exercises/models/exercise.dart';
import 'package:nomorex/features/exercises/providers/exercises_provider.dart';
import 'package:nomorex/features/profile/providers/profile_provider.dart';
import 'package:nomorex/features/workouts/models/workout.dart';
import 'package:nomorex/features/workouts/models/workout_exercise.dart';
import 'package:nomorex/features/workouts/models/workout_set.dart';
import 'package:nomorex/features/workouts/providers/one_rep_max_provider.dart';

class _StubCommunityWorkoutDetailNotifier extends CommunityWorkoutDetailNotifier {
  _StubCommunityWorkoutDetailNotifier(this._workout);
  final Workout _workout;
  @override
  Future<Workout> build(String workoutId) async => _workout;
}

class _StubExercisesNotifier extends ExercisesNotifier {
  _StubExercisesNotifier(this._exercises, {this.onEnsureByName});
  final List<Exercise> _exercises;
  final Exercise Function(String name)? onEnsureByName;

  @override
  Future<List<Exercise>> build() async => _exercises;

  @override
  Future<Exercise> ensureExerciseByName(String name) async {
    if (onEnsureByName == null) {
      throw UnimplementedError('onEnsureByName not stubbed');
    }
    return onEnsureByName!(name);
  }
}

const _backSquat = Exercise(id: 'e1', name: 'Back Squat', isPredefined: true);
const _cleanAndJerk = Exercise(id: 'e2', name: 'Clean & Jerk', isPredefined: true);

/// Someone else's public workout: one percentage set on 'e1', plus whatever
/// [extraExercises] the individual test needs.
Workout _publicWorkout({
  List<WorkoutExercise> extraExercises = const [],
  String? owner = 'BeastModeB',
}) {
  return Workout(
    id: 'w1',
    userId: 'other-user',
    title: 'Squat Focus',
    date: DateTime(2026, 7, 5),
    updatedAt: DateTime(2026, 7, 5),
    workoutGroupId: 'g1',
    isPublic: true,
    ownerDisplayName: owner,
    exercises: [
      const WorkoutExercise(
        id: 'we1',
        workoutId: 'w1',
        exerciseId: 'e1',
        exerciseName: 'Back Squat',
        position: 0,
        sets: [
          WorkoutSet(
            id: 's1',
            workoutExerciseId: 'we1',
            position: 0,
            weightMode: 'percentage',
            targetReps: 5,
            percentage: 80,
          ),
        ],
      ),
      ...extraExercises,
    ],
  );
}

Future<void> pumpCommunityDetail(
  WidgetTester tester, {
  required Workout workout,
  Map<String, double> oneRepMaxes = const {},
  Map<String, double> oneRepMaxesByName = const {},
  List<Exercise> viewerExercises = const [_backSquat, _cleanAndJerk],
  String unit = 'kg',
  Exercise Function(String name)? onEnsureByName,
  GoRouter? router,
}) async {
  final overrides = [
    communityWorkoutDetailProvider('w1').overrideWith(
      () => _StubCommunityWorkoutDetailNotifier(workout),
    ),
    oneRepMaxProvider.overrideWith((ref) async => oneRepMaxes),
    oneRepMaxByNameProvider.overrideWith((ref) async => oneRepMaxesByName),
    exercisesProvider.overrideWith(
      () => _StubExercisesNotifier(viewerExercises, onEnsureByName: onEnsureByName),
    ),
    unitPreferenceProvider.overrideWithValue(unit),
  ];

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: router != null
          ? MaterialApp.router(theme: AppDarkTheme.sleekOrange(), routerConfig: router)
          : MaterialApp(
              theme: AppDarkTheme.sleekOrange(),
              home: const CommunityWorkoutDetailScreen(workoutId: 'w1'),
            ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The color the run of [substring] is actually painted in — the point of the
/// accent is that it's visibly distinct, so asserting the string alone would
/// miss a regression that dropped the styling.
Color? colorOfSpan(WidgetTester tester, String substring) {
  for (final richText in tester.widgetList<RichText>(find.byType(RichText))) {
    Color? found;
    richText.text.visitChildren((span) {
      if (span is TextSpan && (span.text?.contains(substring) ?? false)) {
        found = span.style?.color;
        return false;
      }
      return true;
    });
    if (found != null) return found;
  }
  return null;
}

void main() {
  testWidgets('renders exercises and sets read-only, with no edit affordances',
      (tester) async {
    await pumpCommunityDetail(tester, workout: _publicWorkout());

    expect(find.text('Squat Focus'), findsOneWidget);
    expect(find.text('Back Squat'), findsOneWidget);

    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.byType(IconButton), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Read only'), findsOneWidget);
  });

  testWidgets('attributes the workout to its owner', (tester) async {
    await pumpCommunityDetail(tester, workout: _publicWorkout());

    expect(find.textContaining('by BeastModeB'), findsOneWidget);
  });

  testWidgets('falls back to the anonymous label when the owner has no name',
      (tester) async {
    await pumpCommunityDetail(tester, workout: _publicWorkout(owner: null));

    expect(find.textContaining('by $kAnonymousOwnerName'), findsOneWidget);
  });

  testWidgets('a percentage set resolves against the VIEWER\'s 1RM and accents the weight',
      (tester) async {
    await pumpCommunityDetail(
      tester,
      workout: _publicWorkout(),
      oneRepMaxes: {'e1': 100},
    );

    expect(find.textContaining('5 reps · 80% 1RM · 80.0 kg'), findsOneWidget);
    expect(find.text('set PR'), findsNothing);

    final accent = AppDarkTheme.sleekOrange()
        .extension<NomorexDarkTokens>()!
        .secondaryAccent;
    expect(colorOfSpan(tester, '80.0 kg'), accent);
  });

  testWidgets('a percentage set with no 1RM for the viewer shows a "set PR" link',
      (tester) async {
    await pumpCommunityDetail(tester, workout: _publicWorkout());

    expect(find.textContaining('5 reps · 80% 1RM'), findsOneWidget);
    expect(find.text('set PR'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is InkWell && w.child is Text && (w.child as Text).data == 'set PR',
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping "set PR" navigates to the add-PR route for the basis exercise',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/community/w1',
      routes: [
        GoRoute(
          path: '/community/w1',
          builder: (_, _) => const CommunityWorkoutDetailScreen(workoutId: 'w1'),
        ),
        GoRoute(
          path: '/prs/add',
          builder: (_, state) => Text('destination:${state.uri.queryParameters['exerciseId']}'),
        ),
      ],
    );

    await pumpCommunityDetail(tester, workout: _publicWorkout(), router: router);

    await tester.tap(find.text('set PR'));
    await tester.pumpAndSettle();

    expect(find.text('destination:e1'), findsOneWidget);
  });

  testWidgets(
      'tapping "set PR" on an exercise the viewer does not have creates their own copy '
      'first, then routes to it', (tester) async {
    String? ensuredName;

    final router = GoRouter(
      initialLocation: '/community/w1',
      routes: [
        GoRoute(
          path: '/community/w1',
          builder: (_, _) => const CommunityWorkoutDetailScreen(workoutId: 'w1'),
        ),
        GoRoute(
          path: '/prs/add',
          builder: (_, state) => Text('destination:${state.uri.queryParameters['exerciseId']}'),
        ),
      ],
    );

    await pumpCommunityDetail(
      tester,
      workout: _publicWorkout(),
      // 'e1' is the owner's custom exercise — not in the viewer's catalog.
      viewerExercises: const [],
      onEnsureByName: (name) {
        ensuredName = name;
        return const Exercise(id: 'mine-1', name: 'Back Squat', isPredefined: false);
      },
      router: router,
    );

    await tester.tap(find.text('set PR'));
    await tester.pumpAndSettle();

    expect(ensuredName, 'Back Squat');
    expect(find.text('destination:mine-1'), findsOneWidget);
  });

  testWidgets(
      'a PR recorded under the viewer\'s own copy of the owner\'s exercise resolves '
      'the set, even though the ids differ', (tester) async {
    // The set points at the owner's exercise row ('e1'); the viewer's PR for
    // the same lift hangs off a different id in their own catalog, so an
    // id-only lookup would keep showing "set PR" forever after they set one.
    await pumpCommunityDetail(
      tester,
      workout: _publicWorkout(),
      oneRepMaxes: const {'viewers-own-id': 100},
      oneRepMaxesByName: const {'back squat': 100},
      viewerExercises: const [],
    );

    expect(find.text('set PR'), findsNothing);
    expect(find.textContaining('5 reps · 80% 1RM · 80.0 kg'), findsOneWidget);
  });

  testWidgets('a set programmed against another lift names that lift', (tester) async {
    final workout = _publicWorkout(
      extraExercises: const [
        WorkoutExercise(
          id: 'we2',
          workoutId: 'w1',
          exerciseId: 'e3',
          exerciseName: 'Front Squat',
          position: 1,
          sets: [
            WorkoutSet(
              id: 's2',
              workoutExerciseId: 'we2',
              position: 0,
              weightMode: 'percentage',
              targetReps: 3,
              percentage: 75,
              basisExerciseId: 'e2',
              basisExerciseName: 'Clean & Jerk',
            ),
          ],
        ),
      ],
    );

    // Only the basis lift has a 1RM — the set must resolve against 'e2', not
    // against its own exercise 'e3'.
    await pumpCommunityDetail(tester, workout: workout, oneRepMaxes: {'e2': 120});

    expect(find.textContaining('3 reps · 75% of Clean & Jerk · 90.0 kg'), findsOneWidget);
  });

  testWidgets('absolute sets are unchanged and keep the default color', (tester) async {
    final workout = _publicWorkout(
      extraExercises: const [
        WorkoutExercise(
          id: 'we2',
          workoutId: 'w1',
          exerciseId: 'e4',
          exerciseName: 'Reverse Lunge',
          position: 1,
          sets: [
            WorkoutSet(
              id: 's2',
              workoutExerciseId: 'we2',
              position: 0,
              weightMode: 'absolute',
              targetReps: 10,
              absoluteWeightKg: 50,
            ),
          ],
        ),
      ],
    );

    await pumpCommunityDetail(tester, workout: workout, unit: 'both');

    expect(find.text('10 reps · 110 lbs / 50 kg'), findsOneWidget);
  });

  testWidgets('the resolved weight respects the viewer\'s unit preference', (tester) async {
    await pumpCommunityDetail(
      tester,
      workout: _publicWorkout(),
      oneRepMaxes: {'e1': 100},
      unit: 'lbs',
    );

    expect(find.textContaining('5 reps · 80% 1RM · 176.4 lbs'), findsOneWidget);
  });
}
