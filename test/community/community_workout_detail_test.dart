import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/shared/models/one_rep_max.dart';
import 'package:go_router/go_router.dart';
import 'package:nomorex/core/theme/dark_theme.dart';
import 'package:nomorex/core/utils/copy_errors.dart';
import 'package:nomorex/core/utils/owner_name.dart';
import 'package:nomorex/features/auth/providers/auth_provider.dart';
import 'package:nomorex/features/community/providers/community_workout_detail_provider.dart';
import 'package:nomorex/features/community/screens/community_workout_detail_screen.dart';
import 'package:nomorex/features/exercises/models/exercise.dart';
import 'package:nomorex/features/exercises/providers/exercises_provider.dart';
import 'package:nomorex/features/profile/providers/profile_provider.dart';
import 'package:nomorex/features/workouts/models/workout.dart';
import 'package:nomorex/features/workouts/models/workout_exercise.dart';
import 'package:nomorex/features/workouts/models/workout_set.dart';
import 'package:nomorex/features/workouts/providers/one_rep_max_provider.dart';
import 'package:nomorex/features/workouts/providers/workout_copy_count_provider.dart';
import 'package:nomorex/features/workouts/providers/workouts_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

/// Records save/start calls instead of hitting the copy_workout RPC.
class RecordingWorkoutsNotifier extends WorkoutsNotifier {
  RecordingWorkoutsNotifier({this.onSave});
  final Future<String> Function(String sourceId, bool start)? onSave;
  final calls = <({String sourceId, bool start})>[];

  @override
  Future<List<Workout>> build() async => const [];

  @override
  Future<String> saveCommunityWorkout(String sourceWorkoutId, {bool start = false}) async {
    calls.add((sourceId: sourceWorkoutId, start: start));
    if (onSave != null) return onSave!(sourceWorkoutId, start);
    return 'copy-1';
  }
}

User _user(String id) => User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
    );

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
  Map<String, OneRepMax> oneRepMaxes = const {},
  Map<String, OneRepMax> oneRepMaxesByName = const {},
  List<Exercise> viewerExercises = const [_backSquat, _cleanAndJerk],
  String unit = 'kg',
  Exercise Function(String name)? onEnsureByName,
  GoRouter? router,
  String viewerId = 'viewer',
  int copyCount = 0,
  RecordingWorkoutsNotifier? workoutsNotifier,
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
    currentAuthUserProvider.overrideWithValue(_user(viewerId)),
    workoutCopyCountProvider('w1').overrideWith((ref) async => copyCount),
    workoutsProvider.overrideWith(() => workoutsNotifier ?? RecordingWorkoutsNotifier()),
  ];

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      // Always under a GoRouter, as in the app: the save/start actions
      // capture it up front for their SnackBar actions.
      child: MaterialApp.router(
        theme: AppDarkTheme.sleekOrange(),
        routerConfig: router ??
            GoRouter(
              initialLocation: '/community/w1',
              routes: [
                GoRoute(
                  path: '/community/w1',
                  builder: (_, _) => const CommunityWorkoutDetailScreen(workoutId: 'w1'),
                ),
              ],
            ),
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
      oneRepMaxes: const {'e1': OneRepMax.measured(100)},
    );

    expect(find.textContaining('5 reps · 80% 1RM · 80 kg'), findsOneWidget);
    expect(find.text('set PR'), findsNothing);

    final accent = AppDarkTheme.sleekOrange()
        .extension<NomorexDarkTokens>()!
        .secondaryAccent;
    expect(colorOfSpan(tester, '80 kg'), accent);
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
      oneRepMaxes: const {'viewers-own-id': OneRepMax.measured(100)},
      oneRepMaxesByName: const {'back squat': OneRepMax.measured(100)},
      viewerExercises: const [],
    );

    expect(find.text('set PR'), findsNothing);
    expect(find.textContaining('5 reps · 80% 1RM · 80 kg'), findsOneWidget);
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
    await pumpCommunityDetail(tester, workout: workout, oneRepMaxes: const {'e2': OneRepMax.measured(120)});

    expect(find.textContaining('3 reps · 75% of Clean & Jerk · 90 kg'), findsOneWidget);
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
      oneRepMaxes: const {'e1': OneRepMax.measured(100)},
      unit: 'lbs',
    );

    expect(find.textContaining('5 reps · 80% 1RM · 176.4 lbs'), findsOneWidget);
  });

  group('save / start (FR-001, FR-014, FR-018)', () {
    GoRouter routerWithDetail() => GoRouter(
          initialLocation: '/community/w1',
          routes: [
            GoRoute(
              path: '/community/w1',
              builder: (_, _) => const CommunityWorkoutDetailScreen(workoutId: 'w1'),
            ),
            GoRoute(
              path: '/workouts/:id',
              builder: (_, state) => Text('workout:${state.pathParameters['id']}'),
            ),
          ],
        );

    testWidgets("offers Start and Save on another user's workout", (tester) async {
      await pumpCommunityDetail(tester, workout: _publicWorkout());

      expect(find.byKey(const Key('community_workout_start')), findsOneWidget);
      expect(find.byKey(const Key('community_workout_save')), findsOneWidget);
      expect(find.byKey(const Key('community_workout_saved_hint')), findsNothing);
    });

    testWidgets('offers neither on your own workout', (tester) async {
      await pumpCommunityDetail(tester, workout: _publicWorkout(), viewerId: 'other-user');

      expect(find.byKey(const Key('community_workout_start')), findsNothing);
      expect(find.byKey(const Key('community_workout_save')), findsNothing);
    });

    testWidgets('says when the viewer already has copies, but still allows another save',
        (tester) async {
      await pumpCommunityDetail(tester, workout: _publicWorkout(), copyCount: 2);

      expect(find.byKey(const Key('community_workout_saved_hint')), findsOneWidget);
      expect(find.text("You've saved this 2 times"), findsOneWidget);
      final save = tester.widget<ButtonStyleButton>(
        find.byKey(const Key('community_workout_save')),
      );
      expect(save.onPressed, isNotNull);
    });

    testWidgets('Save copies without starting, confirms, and View opens the copy',
        (tester) async {
      final notifier = RecordingWorkoutsNotifier();
      await pumpCommunityDetail(
        tester,
        workout: _publicWorkout(),
        workoutsNotifier: notifier,
        router: routerWithDetail(),
      );

      await tester.ensureVisible(find.byKey(const Key('community_workout_save')));
      await tester.tap(find.byKey(const Key('community_workout_save')));
      await tester.pumpAndSettle();

      expect(notifier.calls, [(sourceId: 'w1', start: false)]);
      expect(find.text('Saved to your workouts'), findsOneWidget);

      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      expect(find.text('workout:copy-1'), findsOneWidget);
    });

    GoRouter routerFromList() => GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () => context.push('/community/w1'),
                  child: const Text('open'),
                ),
              ),
            ),
            GoRoute(
              path: '/community/w1',
              builder: (_, _) => const CommunityWorkoutDetailScreen(workoutId: 'w1'),
            ),
            GoRoute(
              path: '/workouts/:id',
              builder: (_, state) => Text('workout:${state.pathParameters['id']}'),
            ),
          ],
        );

    // The SnackBar lives on the app-wide ScaffoldMessenger, so without the
    // screen closing it, it follows the user back to the list.
    testWidgets('leaving the screen closes its "Saved" SnackBar', (tester) async {
      final router = routerFromList();
      await pumpCommunityDetail(tester, workout: _publicWorkout(), router: router);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('community_workout_save')));
      await tester.tap(find.byKey(const Key('community_workout_save')));
      await tester.pumpAndSettle();
      expect(find.text('Saved to your workouts'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();

      expect(find.text('open'), findsOneWidget);
      expect(find.text('Saved to your workouts'), findsNothing);
    });

    testWidgets('the "Saved" SnackBar times out instead of persisting', (tester) async {
      await pumpCommunityDetail(tester, workout: _publicWorkout());

      await tester.ensureVisible(find.byKey(const Key('community_workout_save')));
      await tester.tap(find.byKey(const Key('community_workout_save')));
      await tester.pumpAndSettle();
      expect(find.text('Saved to your workouts'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Saved to your workouts'), findsNothing);
    });

    // Scrolling the buttons out of the ListView must not dispose them (which
    // would close the SnackBar, or leave View holding a dead context).
    testWidgets('View still opens the copy after scrolling the buttons away', (tester) async {
      final workout = _publicWorkout(extraExercises: [
        for (var i = 0; i < 12; i++)
          WorkoutExercise(
            id: 'x$i',
            workoutId: 'w1',
            exerciseId: 'e1',
            exerciseName: 'Filler $i',
            position: i + 1,
          ),
      ]);
      await pumpCommunityDetail(tester, workout: workout, router: routerFromList());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('community_workout_save')));
      await tester.tap(find.byKey(const Key('community_workout_save')));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('community_workout_save'), skipOffstage: true), findsNothing);

      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      expect(find.text('workout:copy-1'), findsOneWidget);
    });

    testWidgets('Start copies with start and opens the new session', (tester) async {
      final notifier = RecordingWorkoutsNotifier();
      await pumpCommunityDetail(
        tester,
        workout: _publicWorkout(),
        workoutsNotifier: notifier,
        router: routerWithDetail(),
      );

      await tester.ensureVisible(find.byKey(const Key('community_workout_start')));
      await tester.tap(find.byKey(const Key('community_workout_start')));
      await tester.pumpAndSettle();

      expect(notifier.calls, [(sourceId: 'w1', start: true)]);
      expect(find.text('workout:copy-1'), findsOneWidget);
    });

    testWidgets('both buttons are disabled while a copy is in flight', (tester) async {
      final pending = Completer<String>();
      await pumpCommunityDetail(
        tester,
        workout: _publicWorkout(),
        workoutsNotifier: RecordingWorkoutsNotifier(onSave: (_, _) => pending.future),
      );

      await tester.ensureVisible(find.byKey(const Key('community_workout_save')));
      await tester.tap(find.byKey(const Key('community_workout_save')));
      await tester.pump();

      for (final key in ['community_workout_start', 'community_workout_save']) {
        expect(tester.widget<ButtonStyleButton>(find.byKey(Key(key))).onPressed, isNull);
      }

      pending.complete('copy-1');
      await tester.pumpAndSettle();
    });

    testWidgets('a failed save explains why and offers Retry', (tester) async {
      await pumpCommunityDetail(
        tester,
        workout: _publicWorkout(),
        workoutsNotifier: RecordingWorkoutsNotifier(
          onSave: (_, _) => Future.error(
            const PostgrestException(message: 'not_found: gone', code: 'P0001'),
          ),
        ),
      );

      await tester.ensureVisible(find.byKey(const Key('community_workout_save')));
      await tester.tap(find.byKey(const Key('community_workout_save')));
      await tester.pumpAndSettle();

      expect(find.text(copyErrorMessage(
        const PostgrestException(message: 'not_found: gone', code: 'P0001'),
      )), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
