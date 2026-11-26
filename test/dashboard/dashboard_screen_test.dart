import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nomorex/features/ai/models/ai_import_limits.dart';
import 'package:nomorex/features/ai/providers/ai_import_intake_provider.dart';
import 'package:nomorex/features/dashboard/screens/dashboard_screen.dart';
import 'package:nomorex/features/workouts/widgets/elapsed_timer.dart';
import 'package:nomorex/features/personal_bests/models/personal_best.dart';
import 'package:nomorex/features/personal_bests/providers/personal_bests_provider.dart';
import 'package:nomorex/features/programs/models/program_instance.dart';
import 'package:nomorex/features/programs/providers/program_instances_list_provider.dart';
import 'package:nomorex/features/programs/utils/program_stats.dart';
import 'package:nomorex/core/constants/app_constants.dart';
import 'package:nomorex/core/theme/app_theme.dart';
import 'package:nomorex/features/programs/models/program.dart';
import 'package:nomorex/features/programs/providers/programs_provider.dart';
import 'package:nomorex/features/workouts/models/workout.dart';
import 'package:nomorex/features/workouts/providers/workouts_provider.dart';
import 'package:nomorex/features/workouts/providers/finished_workouts_provider.dart';
import 'package:nomorex/features/workouts/providers/in_progress_workouts_provider.dart';
import 'package:nomorex/features/profile/providers/profile_provider.dart';
import 'package:nomorex/shared/widgets/pr_card.dart';
import 'package:nomorex/shared/widgets/program_instance_card.dart';
import 'package:nomorex/shared/widgets/recent_workout_card.dart';
import 'package:nomorex/shared/widgets/workout_in_progress_card.dart';
import 'package:nomorex/features/ai/core/ai_key_store.dart';
import '../ai/core/ai_fakes.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _FailingPersonalBestsNotifier extends PersonalBestsNotifier {
  _FailingPersonalBestsNotifier([this.onRefresh]);
  final VoidCallback? onRefresh;
  @override
  Future<List<PersonalBest>> build() async => throw Exception('PostgrestException: offline');
  @override
  Future<void> refresh() async => onRefresh?.call();
}

class _FailingFinishedWorkoutsNotifier extends FinishedWorkoutsNotifier {
  @override
  Future<List<Workout>> build() async => throw Exception('PostgrestException: offline');
}

/// One PR, so the dashboard isn't a first run and every other section shows
/// its own empty state.
final _onePr = PersonalBest(
  id: 'pr1',
  userId: 'u1',
  exerciseId: 'e1',
  exerciseName: 'Back Squat',
  weightKg: 100,
  reps: 1,
  date: DateTime(2026, 8, 14),
  updatedAt: DateTime(2026, 8, 14),
);

class _PendingPersonalBestsNotifier extends PersonalBestsNotifier {
  @override
  Future<List<PersonalBest>> build() => Completer<List<PersonalBest>>().future;
}

void main() {
  // The AI settings read the provider choice from preferences.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows empty state when no programs are in progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalBestsProvider.overrideWith(
            () => _StubPersonalBestsWithPrsNotifier([_onePr]),
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

    expect(find.text('No program started'), findsOneWidget);
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
    expect(find.descendant(of: find.byType(ProgramInstanceCard), matching: find.byIcon(Icons.chevron_right)), findsOneWidget);
  });

  testWidgets('a program in progress shows its completed-of-total counts', (
    tester,
  ) async {
    final instance = ProgramInstance(
      id: 'run-1',
      programId: 'p1',
      programName: 'Strong Like Bull',
      userId: 'u1',
      startedAt: DateTime(2000, 1, 1),
      status: 'active',
      structure: const [
        StatsWeek([
          StatsDay(id: 'd1', dayOffset: 0, isRest: false),
          StatsDay(id: 'd2', dayOffset: 1, isRest: true),
        ]),
      ],
      workoutStatusByKey: const {'d1': 'finished'},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalBestsProvider.overrideWith(() => _StubPersonalBestsNotifier()),
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

    expect(find.text('1 of 1 week'), findsOneWidget);
    expect(find.text('2 of 2 days'), findsOneWidget);
    expect(find.text('1 of 1 workout'), findsOneWidget);
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
            () => _StubPersonalBestsWithPrsNotifier([_onePr]),
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

    expect(find.text('Nothing in progress'), findsOneWidget);
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
    expect(find.descendant(of: find.byType(WorkoutInProgressCard), matching: find.byIcon(Icons.chevron_right)), findsOneWidget);
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
            () => _StubPersonalBestsWithPrsNotifier([_onePr]),
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
      find.text('Finished workouts show up here'),
      find.byType(ListView),
      const Offset(0, -300),
    );

    expect(find.text('Finished workouts show up here'), findsOneWidget);
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
    expect(find.descendant(of: find.byType(RecentWorkoutCard), matching: find.byIcon(Icons.chevron_right)), findsNWidgets(5));
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
    expect(find.descendant(of: find.byType(PrCard), matching: find.byIcon(Icons.chevron_right)), findsOneWidget);

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
          aiKeyStoreProvider.overrideWithValue(FakeAiKeyStore()),
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

  group('first run: getting started replaces the empty sections', () {
    Future<void> pump(
      WidgetTester tester, {
      bool importEnabled = true,
      List<Program> programs = const [],
      bool prsFail = false,
      Size size = const Size(800, 600),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: '/shell/home',
        routes: [
          GoRoute(path: '/shell/home', builder: (_, _) => const DashboardScreen()),
          for (final (path, label) in [
            (AppConstants.routeAiImport, 'import-screen'),
            (AppConstants.routeCommunity, 'community-tab'),
            (AppConstants.routeProgramNew, 'new-program'),
            (AppConstants.routePrograms, 'programs-tab'),
            (AppConstants.routeAddPr, 'add-pr-screen'),
          ])
            GoRoute(path: path, builder: (_, _) => Text(label)),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          // A failing section stays failed rather than retrying behind the test.
          retry: (_, _) => null,
          overrides: [
            personalBestsProvider.overrideWith(
              () => prsFail ? _FailingPersonalBestsNotifier() : _StubPersonalBestsNotifier(),
            ),
            currentProgramInstancesProvider.overrideWith(() => _EmptyProgramInstancesNotifier()),
            inProgressWorkoutsProvider.overrideWith(() => _EmptyInProgressWorkoutsNotifier()),
            finishedWorkoutsProvider.overrideWith(() => _EmptyFinishedWorkoutsNotifier()),
            programsProvider.overrideWith(() => _StubProgramsNotifier(programs)),
            // A device that can store keys counts as able to import (it offers
            // the settings), so "switched off" here also means it can't.
            aiKeyStoreProvider.overrideWithValue(FakeAiKeyStore(failing: !importEnabled)),
            aiImportLimitsProvider.overrideWith(
              (ref) async => AiImportLimits(
                maxImages: 10,
                maxPdfPages: 10,
                maxImageBytes: 1,
                maxPdfBytes: 1,
                enabled: importEnabled,
              ),
            ),
          ],
          // The app's theme, not stock Material: its full-width buttons are
          // what a Row around the main action has to cope with.
          child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tapKey(WidgetTester tester, String key) async {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
    }

    testWidgets('leads with importing a program, and hides the empty sections', (tester) async {
      await pump(tester);

      expect(find.text('Welcome to NoMoreX'), findsOneWidget);
      final primary = find.byKey(const Key('get_started_primary'));
      expect(find.descendant(of: primary, matching: find.text('Import a program')), findsOneWidget);
      expect(find.text('No program started'), findsNothing);
      expect(find.text('RECENT PRS'), findsNothing);

      await tapKey(tester, 'get_started_primary');
      expect(find.text('import-screen'), findsOneWidget);
    });

    testWidgets('offers Community, building a program and entering maxes', (tester) async {
      await pump(tester);
      await tapKey(tester, 'get_started_community');
      expect(find.text('community-tab'), findsOneWidget);

      await pump(tester);
      await tapKey(tester, 'get_started_build');
      expect(find.text('new-program'), findsOneWidget);

      await pump(tester);
      await tapKey(tester, 'get_started_maxes');
      expect(find.text('add-pr-screen'), findsOneWidget);
    });

    testWidgets('with imports switched off, Community becomes the main action', (tester) async {
      await pump(tester, importEnabled: false);

      final primary = find.byKey(const Key('get_started_primary'));
      expect(find.descendant(of: primary, matching: find.text('Find a program in Community')), findsOneWidget);
      expect(find.text('Import a program'), findsNothing);
      // Not offered twice.
      expect(find.byKey(const Key('get_started_community')), findsNothing);

      await tapKey(tester, 'get_started_primary');
      expect(find.text('community-tab'), findsOneWidget);
    });

    testWidgets('an owner of programs is offered to start one, not build one', (tester) async {
      await pump(
        tester,
        programs: [
          Program(
            id: 'p1',
            userId: 'u1',
            name: 'Block 1',
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        ],
      );

      expect(find.byKey(const Key('get_started_build')), findsNothing);
      await tapKey(tester, 'get_started_programs');
      expect(find.text('programs-tab'), findsOneWidget);
    });

    testWidgets('a section that failed to load still shows its error', (tester) async {
      // Tall enough that every section is built without scrolling.
      await pump(tester, prsFail: true, size: const Size(800, 1600));

      expect(find.text('Welcome to NoMoreX'), findsOneWidget);
      expect(find.text("Couldn't load PRs"), findsOneWidget);
      // Only the failed section joins getting started, not the empty ones.
      expect(find.text('Nothing in progress'), findsNothing);
    });

    testWidgets('fits a phone without overflowing', (tester) async {
      await pump(tester, size: const Size(360, 740));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('get_started_maxes')), findsOneWidget);
    });
  });

  testWidgets('getting started is gone once any section has data', (
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
    expect(find.byKey(const Key('get_started_primary')), findsNothing);
    // Titled after its nav item, not "Dashboard".
    expect(find.widgetWithText(AppBar, 'Home'), findsOneWidget);
    expect(find.text('CURRENT PROGRAMS'), findsOneWidget);
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
            () => _StubProgramInstancesNotifier([
              ProgramInstance(
                id: 'pi1',
                programId: 'p1',
                programName: 'Strong Like Bull',
                userId: 'u1',
                startedAt: DateTime(2026, 1, 1),
                status: 'active',
              ),
            ]),
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
      find.text('Add a PR'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    // dragUntilVisible stops as soon as any part of the label is on screen,
    // which can leave the button's center (where tap() aims) off the bottom.
    await tester.ensureVisible(find.text('Add a PR'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add a PR'));
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
                () => _StubPersonalBestsWithPrsNotifier([_onePr]),
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

          expect(find.text('New workout'), findsOneWidget);
          expect(find.text('Browse workouts'), findsNothing);
          expect(find.text('New program'), findsOneWidget);
          expect(find.text('Start a program'), findsNothing);

          await tapText(tester, 'New workout');
          expect(find.text('new-workout'), findsOneWidget);
        },
      );

      testWidgets('no programs: the CTA opens the new-program screen', (
        tester,
      ) async {
        await pump(tester);
        await tapText(tester, 'New program');
        expect(find.text('new-program'), findsOneWidget);
      });

      testWidgets('existing workouts and programs: offers to browse them', (
        tester,
      ) async {
        await pump(tester, workouts: [workout], programs: [program]);

        expect(find.text('Browse workouts'), findsOneWidget);
        expect(find.text('New workout'), findsNothing);
        expect(find.text('Start a program'), findsOneWidget);
        expect(find.text('New program'), findsNothing);

        await tapText(tester, 'Browse workouts');
        expect(find.text('workouts-tab'), findsOneWidget);
      });
    },
  );

  testWidgets('a recent PR gets the all-time best chip only when it is the best',
      (tester) async {
    PersonalBest pr(String id, String exerciseId, String name, double kg, DateTime date) =>
        PersonalBest(
          id: id,
          userId: 'u1',
          exerciseId: exerciseId,
          exerciseName: name,
          weightKg: kg,
          reps: 1,
          date: date,
          updatedAt: date,
        );

    // Newest first, as the provider orders them. Back Squat's latest entry is
    // lighter than an older one; Deadlift's latest is its heaviest.
    final prs = [
      pr('bs-new', 'e1', 'Back Squat', 100, DateTime(2026, 8, 14)),
      pr('dl-new', 'e2', 'Deadlift', 150, DateTime(2026, 8, 10)),
      pr('bs-old', 'e1', 'Back Squat', 120, DateTime(2026, 1, 1)),
      pr('dl-old', 'e2', 'Deadlift', 140, DateTime(2026, 1, 1)),
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

    Finder chipIn(String name) => find.descendant(
          of: find.ancestor(of: find.text(name), matching: find.byType(PrCard)),
          matching: find.byKey(const Key('pr_card_all_time_best')),
        );

    await tester.dragUntilVisible(
      find.text('Deadlift'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    expect(chipIn('Deadlift'), findsOneWidget);
    expect(chipIn('Back Squat'), findsNothing);
  });

  testWidgets('recent PRs follow the PR date, so back-filled history stays put',
      (tester) async {
    PersonalBest pr(String id, String exerciseId, String name, double kg,
            DateTime date, DateTime savedAt) =>
        PersonalBest(
          id: id,
          userId: 'u1',
          exerciseId: exerciseId,
          exerciseName: name,
          weightKg: kg,
          reps: 1,
          date: date,
          updatedAt: savedAt,
        );

    // Newest *saved* first, as the provider returns them: the 2022 Tall Clean
    // was back-filled today.
    final prs = [
      pr('tc-old', 'e1', 'Tall Clean', 50, DateTime(2022, 10, 19), DateTime(2026, 11, 2)),
      pr('ur', 'e2', 'Upright Row', 52.5, DateTime(2026, 8, 10), DateTime(2026, 8, 10)),
      pr('tc-new', 'e1', 'Tall Clean', 60, DateTime(2026, 11, 1), DateTime(2026, 11, 1)),
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
          unitPreferenceProvider.overrideWithValue('kg'),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Upright Row'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    // Tall Clean shows its Nov 2026 entry, not the back-filled 2022 one.
    final cards = tester.widgetList<PrCard>(find.byType(PrCard)).toList();
    expect(cards.map((c) => c.exerciseName), ['Tall Clean', 'Upright Row']);
    expect(cards.first.weightDisplay, '60 kg');
  });

  group('load failures', () {
    Future<void> pump(
      WidgetTester tester, {
      required PersonalBestsNotifier Function() prs,
      FinishedWorkoutsNotifier Function()? finished,
      Duration? Function(int, Object)? retry,
    }) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          // A failing section stays failed rather than retrying behind the test.
          retry: retry ?? (_, _) => null,
          overrides: [
            personalBestsProvider.overrideWith(prs),
            currentProgramInstancesProvider.overrideWith(
              () => _StubProgramInstancesNotifier([
                ProgramInstance(
                  id: 'pi1',
                  programId: 'p1',
                  programName: 'Strong Like Bull',
                  userId: 'u1',
                  startedAt: DateTime(2026, 1, 1),
                  status: 'active',
                ),
              ]),
            ),
            inProgressWorkoutsProvider.overrideWith(() => _EmptyInProgressWorkoutsNotifier()),
            finishedWorkoutsProvider.overrideWith(finished ?? () => _EmptyFinishedWorkoutsNotifier()),
          ],
          child: MaterialApp(theme: AppTheme.dark(), home: const DashboardScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('while Riverpod retries, the row says so instead of spinning', (tester) async {
      await pump(
        tester,
        prs: () => _FailingPersonalBestsNotifier(),
        retry: (count, _) => count < 1 ? const Duration(seconds: 5) : null,
      );

      expect(find.text("Couldn't load PRs"), findsOneWidget);
      expect(find.text('Trying again…'), findsOneWidget);

      // The one retry fails too, and the row settles on its final message.
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      expect(find.text('Trying again…'), findsNothing);
      expect(find.text('Check your connection and try again.'), findsOneWidget);
    });

    testWidgets('one failed section says what failed, never the raw error, and retries', (tester) async {
      var retried = 0;
      await pump(tester, prs: () => _FailingPersonalBestsNotifier(() => retried++));

      expect(find.text("Couldn't load PRs"), findsOneWidget);
      expect(find.textContaining('PostgrestException'), findsNothing);
      // The rest of the page is unaffected.
      expect(find.text('Strong Like Bull'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(retried, 1);
    });

    testWidgets('several failures become one notice for the page', (tester) async {
      await pump(
        tester,
        prs: () => _FailingPersonalBestsNotifier(),
        finished: () => _FailingFinishedWorkoutsNotifier(),
      );

      expect(find.byKey(const Key('dashboard_load_failure')), findsOneWidget);
      expect(find.text("Couldn't load PRs"), findsNothing);
      expect(find.text("Couldn't load recent workouts"), findsNothing);
      expect(find.text('RECENT PRS'), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Strong Like Bull'), findsOneWidget);
    });
  });

  group('accessibility and loading', () {
    Future<void> pump(WidgetTester tester, {PersonalBestsNotifier Function()? prs}) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            personalBestsProvider.overrideWith(prs ?? () => _StubPersonalBestsWithPrsNotifier([_onePr])),
            currentProgramInstancesProvider.overrideWith(() => _EmptyProgramInstancesNotifier()),
            inProgressWorkoutsProvider.overrideWith(() => _EmptyInProgressWorkoutsNotifier()),
            finishedWorkoutsProvider.overrideWith(() => _EmptyFinishedWorkoutsNotifier()),
          ],
          child: MaterialApp(theme: AppTheme.dark(), home: const DashboardScreen()),
        ),
      );
    }

    testWidgets('an empty row is one button a screen reader can activate', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.text('Nothing in progress')),
        isSemantics(label: 'Nothing in progress\nNew workout', isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets('section labels are headings', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);
      await tester.pumpAndSettle();

      expect(tester.getSemantics(find.text('RECENT PRS')), isSemantics(isHeader: true));
      handle.dispose();
    });

    testWidgets('until every section answers, one spinner and no section labels', (tester) async {
      await pump(tester, prs: () => _PendingPersonalBestsNotifier());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('WORKOUTS IN PROGRESS'), findsNothing);
      expect(find.text('Welcome to NoMoreX'), findsNothing);
    });
  });
}
