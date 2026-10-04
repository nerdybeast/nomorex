import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nomorex/core/constants/app_constants.dart';
import 'package:nomorex/features/workouts/models/workout.dart';
import 'package:nomorex/features/workouts/models/workout_exercise.dart';
import 'package:nomorex/features/workouts/providers/workouts_provider.dart';
import 'package:nomorex/features/workouts/screens/workouts_screen.dart';
import 'package:nomorex/shared/widgets/dashboard_empty_state_card.dart';
import 'package:nomorex/shared/widgets/responsive_layout.dart';

class _StubWorkoutsNotifier extends WorkoutsNotifier {
  _StubWorkoutsNotifier(this._workouts);
  final List<Workout> _workouts;
  @override
  Future<List<Workout>> build() async => _workouts;
}

class _RecordingWorkoutsNotifier extends WorkoutsNotifier {
  _RecordingWorkoutsNotifier(this.onRefresh);
  final VoidCallback onRefresh;
  @override
  Future<List<Workout>> build() async => const [];
  @override
  Future<void> refresh() async => onRefresh();
}

void main() {
  testWidgets(
    'a workout card previews its exercises, counts them and shows its status',
    (tester) async {
      final workout = Workout(
        id: 'w1',
        userId: 'u1',
        title: 'Push Day',
        date: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
        workoutGroupId: 'w1',
        status: 'in_progress',
        exercises: [
          for (var i = 0; i < 4; i++)
            WorkoutExercise(
              id: 'e$i',
              workoutId: 'w1',
              exerciseId: 'x$i',
              exerciseName: ['Bench', 'OHP', 'Dip', 'Fly'][i],
              position: i,
            ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workoutsProvider.overrideWith(
              () => _StubWorkoutsNotifier([workout]),
            ),
          ],
          child: const MaterialApp(home: WorkoutsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bench · OHP · Dip  +1 more'), findsOneWidget);
      expect(find.text('4 exercises'), findsOneWidget);
      expect(find.text('In progress'), findsOneWidget);
    },
  );

  testWidgets('no workouts shows an empty-state card with a create button', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutsProvider.overrideWith(() => _StubWorkoutsNotifier(const [])),
        ],
        child: const MaterialApp(home: WorkoutsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DashboardEmptyStateCard), findsOneWidget);
    expect(find.text('No workouts yet.'), findsOneWidget);
    expect(find.text('Create your first workout'), findsOneWidget);
  });

  testWidgets('the empty-state button opens the new-workout route', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const WorkoutsScreen()),
        GoRoute(
          path: AppConstants.routeWorkoutNew,
          builder: (_, _) => const Text('new-workout-screen'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutsProvider.overrideWith(() => _StubWorkoutsNotifier(const [])),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Create your first workout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create your first workout'));
    await tester.pumpAndSettle();

    expect(find.text('new-workout-screen'), findsOneWidget);
  });

  testWidgets(
    'the list leaves room to scroll clear of the shell FAB on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final workouts = [
        Workout(
          id: 'w1',
          userId: 'u1',
          title: 'Push Day',
          date: DateTime(2026, 7, 1),
          updatedAt: DateTime(2026, 7, 1),
          workoutGroupId: 'w1',
        ),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workoutsProvider.overrideWith(
              () => _StubWorkoutsNotifier(workouts),
            ),
          ],
          child: const MaterialApp(home: WorkoutsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final padding = tester
          .widget<ListView>(find.byType(ListView))
          .padding!
          .resolve(TextDirection.ltr);
      expect(padding.bottom, 16 + kShellFabClearance);
    },
  );

  testWidgets(
    'no extra FAB clearance on wide layouts (the + lives in the rail)',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final workouts = [
        Workout(
          id: 'w1',
          userId: 'u1',
          title: 'Push Day',
          date: DateTime(2026, 7, 1),
          updatedAt: DateTime(2026, 7, 1),
          workoutGroupId: 'w1',
        ),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workoutsProvider.overrideWith(
              () => _StubWorkoutsNotifier(workouts),
            ),
          ],
          child: const MaterialApp(home: WorkoutsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final padding = tester
          .widget<ListView>(find.byType(ListView))
          .padding!
          .resolve(TextDirection.ltr);
      expect(padding.bottom, 16);
    },
  );

  testWidgets('search field filters the workouts list by title', (
    tester,
  ) async {
    final workouts = [
      Workout(
        id: 'w1',
        userId: 'u1',
        title: 'Push Day',
        date: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
        workoutGroupId: 'w1',
      ),
      Workout(
        id: 'w2',
        userId: 'u1',
        title: 'Pull Day',
        date: DateTime(2026, 7, 2),
        updatedAt: DateTime(2026, 7, 2),
        workoutGroupId: 'w2',
      ),
      Workout(
        id: 'w3',
        userId: 'u1',
        title: 'Leg Day',
        date: DateTime(2026, 7, 3),
        updatedAt: DateTime(2026, 7, 3),
        workoutGroupId: 'w3',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutsProvider.overrideWith(() => _StubWorkoutsNotifier(workouts)),
        ],
        child: const MaterialApp(home: WorkoutsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Push Day'), findsOneWidget);
    expect(find.text('Pull Day'), findsOneWidget);
    expect(find.text('Leg Day'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Push');
    await tester.pumpAndSettle();

    expect(find.text('Push Day'), findsOneWidget);
    expect(find.text('Pull Day'), findsNothing);
    expect(find.text('Leg Day'), findsNothing);
  });

  testWidgets('search with no matches shows an empty-state message', (
    tester,
  ) async {
    final workouts = [
      Workout(
        id: 'w1',
        userId: 'u1',
        title: 'Push Day',
        date: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
        workoutGroupId: 'w1',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutsProvider.overrideWith(() => _StubWorkoutsNotifier(workouts)),
        ],
        child: const MaterialApp(home: WorkoutsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();

    expect(find.text('No workouts match your search.'), findsOneWidget);
  });

  testWidgets('tapping the refresh icon calls refresh on the notifier', (
    tester,
  ) async {
    var refreshed = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutsProvider.overrideWith(
            () => _RecordingWorkoutsNotifier(() => refreshed = true),
          ),
        ],
        child: const MaterialApp(home: WorkoutsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    expect(refreshed, isTrue);
  });

  testWidgets(
    'tapping the history icon navigates to the unfiltered history route',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/workouts',
        routes: [
          GoRoute(path: '/workouts', builder: (_, _) => const WorkoutsScreen()),
          GoRoute(
            path: '/workouts/history',
            builder: (_, state) =>
                Text('history:${state.uri.queryParameters['groupId']}'),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workoutsProvider.overrideWith(
              () => _StubWorkoutsNotifier(const []),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();

      expect(find.text('history:null'), findsOneWidget);
    },
  );
}
