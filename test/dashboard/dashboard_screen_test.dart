import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nomorex/features/dashboard/screens/dashboard_screen.dart';
import 'package:nomorex/features/workouts/widgets/elapsed_timer.dart';
import 'package:nomorex/features/personal_bests/models/personal_best.dart';
import 'package:nomorex/features/personal_bests/providers/personal_bests_provider.dart';
import 'package:nomorex/features/programs/models/program_instance.dart';
import 'package:nomorex/features/programs/providers/program_instances_list_provider.dart';
import 'package:nomorex/core/constants/app_constants.dart';
import 'package:nomorex/features/programs/models/program.dart';
import 'package:nomorex/features/programs/providers/programs_provider.dart';
import 'package:nomorex/features/workouts/models/workout.dart';
import 'package:nomorex/features/workouts/providers/workouts_provider.dart';
import 'package:nomorex/features/workouts/providers/finished_workouts_provider.dart';
import 'package:nomorex/features/workouts/providers/in_progress_workouts_provider.dart';
import 'package:nomorex/shared/widgets/pr_card.dart';

class _StubPersonalBestsNotifier extends PersonalBestsNotifier {
  @override
  Future<List<PersonalBest>> build() async => [];
}

class _EmptyProgramInstancesNotifier extends CurrentProgramInstancesNotifier {
  @override
  Future<List<ProgramInstance>> build() async => [];
}

class _StubProgramInstancesNotifier extends CurrentProgramInstancesNotifier {
  _StubProgramInstancesNotifier(this._instances);
  final List<ProgramInstance> _instances;
  @override
  Future<List<ProgramInstance>> build() async => _instances;
}

class _EmptyInProgressWorkoutsNotifier extends InProgressWorkoutsNotifier {
  @override
  Future<List<Workout>> build() async => [];
}

class _StubInProgressWorkoutsNotifier extends InProgressWorkoutsNotifier {
  _StubInProgressWorkoutsNotifier(this._workouts);
  final List<Workout> _workouts;
  @override
  Future<List<Workout>> build() async => _workouts;
}

class _StubPersonalBestsWithPrsNotifier extends PersonalBestsNotifier {
  _StubPersonalBestsWithPrsNotifier(this._prs);
  final List<PersonalBest> _prs;
  @override
  Future<List<PersonalBest>> build() async => _prs;
}

class _RecordingPersonalBestsNotifier extends PersonalBestsNotifier {
  _RecordingPersonalBestsNotifier(this.onRefresh);
  final VoidCallback onRefresh;
  @override
  Future<List<PersonalBest>> build() async => [];
  @override
  Future<void> refresh() async => onRefresh();
}

class _RecordingProgramInstancesNotifier
    extends CurrentProgramInstancesNotifier {
  _RecordingProgramInstancesNotifier(this.onRefresh);
  final VoidCallback onRefresh;
  @override
  Future<List<ProgramInstance>> build() async => [];
  @override
  Future<void> refresh() async => onRefresh();
}

class _RecordingInProgressWorkoutsNotifier extends InProgressWorkoutsNotifier {
  _RecordingInProgressWorkoutsNotifier(this.onRefresh);
  final VoidCallback onRefresh;
  @override
  Future<List<Workout>> build() async => [];
  @override
  Future<void> refresh() async => onRefresh();
}

class _EmptyFinishedWorkoutsNotifier extends FinishedWorkoutsNotifier {
  @override
  Future<List<Workout>> build() async => [];
}

class _StubFinishedWorkoutsNotifier extends FinishedWorkoutsNotifier {
  _StubFinishedWorkoutsNotifier(this._workouts);
  final List<Workout> _workouts;
  @override
  Future<List<Workout>> build() async => _workouts;
}

class _RecordingFinishedWorkoutsNotifier extends FinishedWorkoutsNotifier {
  _RecordingFinishedWorkoutsNotifier(this.onRefresh);
  final VoidCallback onRefresh;
  @override
  Future<List<Workout>> build() async => [];
  @override
  Future<void> refresh() async => onRefresh();
}

class _StubWorkoutsNotifier extends WorkoutsNotifier {
  _StubWorkoutsNotifier(this.workouts);
  final List<Workout> workouts;
  @override
  Future<List<Workout>> build() async => workouts;
}

class _StubProgramsNotifier extends ProgramsNotifier {
  _StubProgramsNotifier(this.programs);
  final List<Program> programs;
  @override
  Future<List<Program>> build() async => programs;
}

void main() {
  testWidgets('shows empty state when no programs are in progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalBestsProvider.overrideWith(
            () => _StubPersonalBestsNotifier(),
          ),
          currentProgramInstancesProvider.overrideWith(
            () => _EmptyProgramInstancesNotifier(),
          ),
          inProgressWorkoutsProvider.overrideWith(
            () => _EmptyInProgressWorkoutsNotifier(),
          ),
          finishedWorkoutsProvider.overrideWith(
            () => _EmptyFinishedWorkoutsNotifier(),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No programs currently in progress.'), findsOneWidget);
  });

  testWidgets('shows a card for an active program instance', (tester) async {
    final instance = ProgramInstance(
      id: 'pi1',
      programId: 'p1',
      programName: 'Strong Like Bull',
      userId: 'u1',
      startedAt: DateTime.now().subtract(const Duration(days: 2)),
      status: 'active',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalBestsProvider.overrideWith(
            () => _StubPersonalBestsNotifier(),
          ),
          currentProgramInstancesProvider.overrideWith(
            () => _StubProgramInstancesNotifier([instance]),
          ),
          inProgressWorkoutsProvider.overrideWith(
            () => _EmptyInProgressWorkoutsNotifier(),
          ),
          finishedWorkoutsProvider.overrideWith(
            () => _EmptyFinishedWorkoutsNotifier(),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Strong Like Bull'), findsOneWidget);
    expect(find.textContaining('In progress'), findsOneWidget);
    // The card navigates to the instance detail screen, so it carries the
    // app-wide "this row goes somewhere" chevron.
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('shows an upcoming program as upcoming', (tester) async {
    final instance = ProgramInstance(
      id: 'pi1',
      programId: 'p1',
      programName: 'Strong Like Bull',
      userId: 'u1',
      startedAt: DateTime.now().add(const Duration(days: 5)),
      status: 'active',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalBestsProvider.overrideWith(
            () => _StubPersonalBestsNotifier(),
          ),
          currentProgramInstancesProvider.overrideWith(
            () => _StubProgramInstancesNotifier([instance]),
          ),
          inProgressWorkoutsProvider.overrideWith(
            () => _EmptyInProgressWorkoutsNotifier(),
          ),
          finishedWorkoutsProvider.overrideWith(
            () => _EmptyFinishedWorkoutsNotifier(),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Upcoming'), findsOneWidget);
  });

  testWidgets('shows empty state when no workouts are in progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalBestsProvider.overrideWith(
            () => _StubPersonalBestsNotifier(),
          ),
          currentProgramInstancesProvider.overrideWith(
            () => _EmptyProgramInstancesNotifier(),
          ),
          inProgressWorkoutsProvider.overrideWith(
            () => _EmptyInProgressWorkoutsNotifier(),
          ),
          finishedWorkoutsProvider.overrideWith(
            () => _EmptyFinishedWorkoutsNotifier(),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No workouts currently in progress.'), findsOneWidget);
  });

  testWidgets('shows a card for an in-progress workout', (tester) async {
    final workout = Workout(
      id: 'w1',
      userId: 'u1',
      title: 'Push Day',
      date: DateTime(2026, 8, 11),
      updatedAt: DateTime(2026, 8, 11),
      workoutGroupId: 'g1',
      status: 'in_progress',
      startedAt: DateTime(2026, 8, 11, 14, 45),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalBestsProvider.overrideWith(
            () => _StubPersonalBestsNotifier(),
          ),
          currentProgramInstancesProvider.overrideWith(
            () => _EmptyProgramInstancesNotifier(),
          ),
          inProgressWorkoutsProvider.overrideWith(
            () => _StubInProgressWorkoutsNotifier([workout]),
          ),
          finishedWorkoutsProvider.overrideWith(
            () => _EmptyFinishedWorkoutsNotifier(),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    // pump(), not pumpAndSettle(): the card's ElapsedTimer runs a real
    // 1-second ticker for an in-progress workout, so the tree never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Push Day'), findsOneWidget);
    expect(find.textContaining('In progress'), findsOneWidget);
    expect(find.byType(ElapsedTimer), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('shows a card for a paused workout', (tester) async {
    final workout = Workout(
      id: 'w1',
      userId: 'u1',
      title: 'Push Day',
      date: DateTime(2026, 8, 11),
      updatedAt: DateTime(2026, 8, 11),
      workoutGroupId: 'g1',
      status: 'paused',
      startedAt: DateTime(2026, 8, 11, 14, 45),
      pausedAt: DateTime(2026, 8, 11, 15, 0),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalBestsProvider.overrideWith(
            () => _StubPersonalBestsNotifier(),
          ),
          currentProgramInstancesProvider.overrideWith(
            () => _EmptyProgramInstancesNotifier(),
          ),
          inProgressWorkoutsProvider.overrideWith(
            () => _StubInProgressWorkoutsNotifier([workout]),
          ),
          finishedWorkoutsProvider.overrideWith(
            () => _EmptyFinishedWorkoutsNotifier(),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Push Day'), findsOneWidget);
    expect(find.textContaining('Paused'), findsOneWidget);
    // 14:45 -> 15:00 with no prior pause cycles.
    expect(find.text('00:15:00'), findsOneWidget);
  });

  testWidgets('shows empty state when no workouts have been completed', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalBestsProvider.overrideWith(
            () => _StubPersonalBestsNotifier(),
          ),
          currentProgramInstancesProvider.overrideWith(
            () => _EmptyProgramInstancesNotifier(),
          ),
          inProgressWorkoutsProvider.overrideWith(
            () => _EmptyInProgressWorkoutsNotifier(),
          ),
          finishedWorkoutsProvider.overrideWith(
            () => _EmptyFinishedWorkoutsNotifier(),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // The taller empty-state cards push the last section below the default
    // test viewport's cache extent, so it isn't built until scrolled into view.
    await tester.dragUntilVisible(
      find.text('No completed workouts yet.'),
      find.byType(ListView),
      const Offset(0, -300),
    );

    expect(find.text('No completed workouts yet.'), findsOneWidget);
  });

  testWidgets('shows up to 5 recent workouts, most recently completed first', (
    tester,
  ) async {
    final finished = List.generate(
      6,
      (i) => Workout(
        id: 'w$i',
        userId: 'u1',
        title: 'Workout $i',
        date: DateTime(2026, 8, i + 1),
        updatedAt: DateTime(2026, 8, i + 1),
        workoutGroupId: 'g$i',
        status: 'finished',
        startedAt: DateTime(2026, 8, i + 1, 9),
        finishedAt: DateTime(2026, 8, i + 1, 10),
      ),
    );
    // finishedWorkoutsProvider already orders newest-first; the dashboard
    // just takes the first 5 as-is.
    final newestFirst = finished.reversed.toList();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalBestsProvider.overrideWith(
            () => _StubPersonalBestsNotifier(),
          ),
          currentProgramInstancesProvider.overrideWith(
            () => _EmptyProgramInstancesNotifier(),
          ),
          inProgressWorkoutsProvider.overrideWith(
            () => _EmptyInProgressWorkoutsNotifier(),
          ),
          finishedWorkoutsProvider.overrideWith(
            () => _StubFinishedWorkoutsNotifier(newestFirst),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // The taller empty-state cards above this section push it below the
    // default test viewport's cache extent, so scroll it into view first.
    await tester.dragUntilVisible(
      find.text('Workout 5'),
      find.byType(ListView),
      const Offset(0, -300),
    );

    expect(find.text('Workout 5'), findsOneWidget);
    expect(find.text('Workout 1'), findsOneWidget);
    expect(find.text('Workout 0'), findsNothing);
    // Every recent-workout card navigates to the workout, so each gets a chevron.
    expect(find.byIcon(Icons.chevron_right), findsNWidgets(5));
  });

  testWidgets('shows the note on a recent PR, clipped to two lines', (
    tester,
  ) async {
    final prs = [
      PersonalBest(
        id: '1',
        userId: 'u1',
        exerciseId: 'e1',
        exerciseName: 'Back Squat',
        weightKg: 100,
        reps: 1,
        date: DateTime(2026, 8, 14),
        notes: 'Felt strong, belt only.',
        updatedAt: DateTime(2026, 8, 14),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalBestsProvider.overrideWith(
            () => _StubPersonalBestsWithPrsNotifier(prs),
          ),
          currentProgramInstancesProvider.overrideWith(
            () => _EmptyProgramInstancesNotifier(),
          ),
          inProgressWorkoutsProvider.overrideWith(
            () => _EmptyInProgressWorkoutsNotifier(),
          ),
          finishedWorkoutsProvider.overrideWith(
            () => _EmptyFinishedWorkoutsNotifier(),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final noteFinder = find.text('Felt strong, belt only.');
    await tester.dragUntilVisible(
      noteFinder,
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(noteFinder, findsOneWidget);
    expect(tester.widget<Text>(noteFinder).maxLines, 2);
  });

  testWidgets('tapping a recent PR opens that exercise\'s history', (
    tester,
  ) async {
    final prs = [
      PersonalBest(
        id: '1',
        userId: 'u1',
        exerciseId: 'e1',
        exerciseName: 'Back Squat',
        weightKg: 100,
        reps: 1,
        date: DateTime(2026, 8, 14),
        updatedAt: DateTime(2026, 8, 14),
      ),
    ];

    final router = GoRouter(
      initialLocation: '/shell/home',
      routes: [
        GoRoute(
          path: '/shell/home',
          builder: (_, _) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/prs/:exerciseId/history',
          builder: (_, state) =>
              Text('history:${state.pathParameters['exerciseId']}'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalBestsProvider.overrideWith(
            () => _StubPersonalBestsWithPrsNotifier(prs),
          ),
          currentProgramInstancesProvider.overrideWith(
            () => _EmptyProgramInstancesNotifier(),
          ),
          inProgressWorkoutsProvider.overrideWith(
            () => _EmptyInProgressWorkoutsNotifier(),
          ),
          finishedWorkoutsProvider.overrideWith(
            () => _EmptyFinishedWorkoutsNotifier(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.byType(PrCard),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    // The card navigates, so it carries the chevron.
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);

    await tester.tap(find.byType(PrCard));
    await tester.pumpAndSettle();

    expect(find.text('history:e1'), findsOneWidget);
  });

  testWidgets('tapping the refresh icon refreshes all four data sources', (
    tester,
  ) async {
    var prsRefreshed = false;
    var instancesRefreshed = false;
    var workoutsRefreshed = false;
    var finishedWorkoutsRefreshed = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalBestsProvider.overrideWith(
            () => _RecordingPersonalBestsNotifier(() => prsRefreshed = true),
          ),
          currentProgramInstancesProvider.overrideWith(
            () => _RecordingProgramInstancesNotifier(
              () => instancesRefreshed = true,
            ),
          ),
          inProgressWorkoutsProvider.overrideWith(
            () => _RecordingInProgressWorkoutsNotifier(
              () => workoutsRefreshed = true,
            ),
          ),
          finishedWorkoutsProvider.overrideWith(
            () => _RecordingFinishedWorkoutsNotifier(
              () => finishedWorkoutsRefreshed = true,
            ),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    expect(prsRefreshed, isTrue);
    expect(instancesRefreshed, isTrue);
    expect(workoutsRefreshed, isTrue);
    expect(finishedWorkoutsRefreshed, isTrue);
  });

  testWidgets('shows the welcome banner when all four sections are empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalBestsProvider.overrideWith(
            () => _StubPersonalBestsNotifier(),
          ),
          currentProgramInstancesProvider.overrideWith(
            () => _EmptyProgramInstancesNotifier(),
          ),
          inProgressWorkoutsProvider.overrideWith(
            () => _EmptyInProgressWorkoutsNotifier(),
          ),
          finishedWorkoutsProvider.overrideWith(
            () => _EmptyFinishedWorkoutsNotifier(),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to NoMoreX'), findsOneWidget);
  });

  testWidgets('hides the welcome banner when at least one section has data', (
    tester,
  ) async {
    final instance = ProgramInstance(
      id: 'pi1',
      programId: 'p1',
      programName: 'Strong Like Bull',
      userId: 'u1',
      startedAt: DateTime.now().subtract(const Duration(days: 2)),
      status: 'active',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalBestsProvider.overrideWith(
            () => _StubPersonalBestsNotifier(),
          ),
          currentProgramInstancesProvider.overrideWith(
            () => _StubProgramInstancesNotifier([instance]),
          ),
          inProgressWorkoutsProvider.overrideWith(
            () => _EmptyInProgressWorkoutsNotifier(),
          ),
          finishedWorkoutsProvider.overrideWith(
            () => _EmptyFinishedWorkoutsNotifier(),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to NoMoreX'), findsNothing);
  });

  testWidgets('tapping the Recent PRs empty-state CTA opens Add PR', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/shell/home',
      routes: [
        GoRoute(
          path: '/shell/home',
          builder: (_, _) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/prs/add',
          builder: (_, _) => const Text('add-pr-screen'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalBestsProvider.overrideWith(
            () => _StubPersonalBestsNotifier(),
          ),
          currentProgramInstancesProvider.overrideWith(
            () => _EmptyProgramInstancesNotifier(),
          ),
          inProgressWorkoutsProvider.overrideWith(
            () => _EmptyInProgressWorkoutsNotifier(),
          ),
          finishedWorkoutsProvider.overrideWith(
            () => _EmptyFinishedWorkoutsNotifier(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Log your first PR'),
      find.byType(ListView),
      const Offset(0, -300),
    );

    await tester.tap(find.text('Log your first PR'));
    await tester.pumpAndSettle();

    expect(find.text('add-pr-screen'), findsOneWidget);
  });

  group(
    'empty-state CTAs depend on whether the user has any workouts/programs',
    () {
      Future<void> pump(
        WidgetTester tester, {
        List<Workout> workouts = const [],
        List<Program> programs = const [],
      }) async {
        final router = GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
            GoRoute(
              path: AppConstants.routeWorkoutNew,
              builder: (_, _) => const Text('new-workout'),
            ),
            GoRoute(
              path: AppConstants.routeWorkouts,
              builder: (_, _) => const Text('workouts-tab'),
            ),
            GoRoute(
              path: AppConstants.routeProgramNew,
              builder: (_, _) => const Text('new-program'),
            ),
            GoRoute(
              path: AppConstants.routePrograms,
              builder: (_, _) => const Text('programs-tab'),
            ),
          ],
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              personalBestsProvider.overrideWith(
                () => _StubPersonalBestsNotifier(),
              ),
              currentProgramInstancesProvider.overrideWith(
                () => _EmptyProgramInstancesNotifier(),
              ),
              inProgressWorkoutsProvider.overrideWith(
                () => _EmptyInProgressWorkoutsNotifier(),
              ),
              finishedWorkoutsProvider.overrideWith(
                () => _EmptyFinishedWorkoutsNotifier(),
              ),
              workoutsProvider.overrideWith(
                () => _StubWorkoutsNotifier(workouts),
              ),
              programsProvider.overrideWith(
                () => _StubProgramsNotifier(programs),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> tapText(WidgetTester tester, String text) async {
        await tester.ensureVisible(find.text(text));
        await tester.pumpAndSettle();
        await tester.tap(find.text(text));
        await tester.pumpAndSettle();
      }

      final workout = Workout(
        id: 'w1',
        userId: 'u1',
        title: 'Leg day',
        date: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        workoutGroupId: 'g1',
      );
      final program = Program(
        id: 'p1',
        userId: 'u1',
        name: 'Block 1',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      testWidgets(
        'no workouts or programs: offers to create the first of each',
        (tester) async {
          await pump(tester);

          expect(find.text('Create your first workout'), findsOneWidget);
          expect(find.text('Browse workouts'), findsNothing);
          expect(find.text('Create your first program'), findsOneWidget);
          expect(find.text('Browse programs'), findsNothing);

          await tapText(tester, 'Create your first workout');
          expect(find.text('new-workout'), findsOneWidget);
        },
      );

      testWidgets('no programs: the CTA opens the new-program screen', (
        tester,
      ) async {
        await pump(tester);
        await tapText(tester, 'Create your first program');
        expect(find.text('new-program'), findsOneWidget);
      });

      testWidgets('existing workouts and programs: offers to browse them', (
        tester,
      ) async {
        await pump(tester, workouts: [workout], programs: [program]);

        expect(find.text('Browse workouts'), findsOneWidget);
        expect(find.text('Create your first workout'), findsNothing);
        expect(find.text('Browse programs'), findsOneWidget);
        expect(find.text('Create your first program'), findsNothing);

        await tapText(tester, 'Browse workouts');
        expect(find.text('workouts-tab'), findsOneWidget);
      });
    },
  );
}
