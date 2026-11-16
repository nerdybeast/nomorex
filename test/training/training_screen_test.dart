import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nomorex/core/theme/app_theme.dart';
import 'package:nomorex/features/personal_bests/models/personal_best.dart';
import 'package:nomorex/features/personal_bests/providers/personal_bests_provider.dart';
import 'package:nomorex/features/programs/models/program.dart';
import 'package:nomorex/features/programs/models/program_instance.dart';
import 'package:nomorex/features/programs/providers/program_instances_list_provider.dart';
import 'package:nomorex/features/programs/providers/programs_provider.dart';
import 'package:nomorex/features/shell/nav_section.dart';
import 'package:nomorex/features/shell/providers/training_view_provider.dart';
import 'package:nomorex/features/training/training_routes.dart';
import 'package:nomorex/features/workouts/models/workout.dart';
import 'package:nomorex/features/workouts/providers/workouts_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Programs extends ProgramsNotifier {
  @override
  Future<List<Program>> build() async => [_program('p1', 'ZT 6 Week Program')];
}

class _ArchivedPrograms extends ArchivedProgramsNotifier {
  @override
  Future<List<Program>> build() async => [_program('p2', 'Old Block')];
}

class _Runs extends CurrentProgramInstancesNotifier {
  @override
  Future<List<ProgramInstance>> build() async => const [];
}

class _Workouts extends WorkoutsNotifier {
  @override
  Future<List<Workout>> build() async => [_workout('w1', 'Push Day')];
}

class _ArchivedWorkouts extends ArchivedWorkoutsNotifier {
  @override
  Future<List<Workout>> build() async => const [];
}

class _Prs extends PersonalBestsNotifier {
  @override
  Future<List<PersonalBest>> build() async => [
        PersonalBest(
          id: 'pb1',
          userId: 'u1',
          exerciseId: 'e1',
          exerciseName: 'Snatch',
          weightKg: 95,
          reps: 1,
          date: DateTime(2026, 11, 2),
          updatedAt: DateTime(2026, 11, 2),
        ),
      ];
}

Program _program(String id, String name) => Program(
      id: id,
      userId: 'u1',
      name: name,
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
    );

Workout _workout(String id, String title) => Workout(
      id: id,
      userId: 'u1',
      title: title,
      date: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 1),
      workoutGroupId: id,
    );

/// Training's real routes, plus stand-ins for the history screens its app bar
/// opens. Returns the router so tests can read where it ended up.
Future<GoRouter> _pump(WidgetTester tester, String initial) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late final GoRouter router;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        programsProvider.overrideWith(_Programs.new),
        archivedProgramsProvider.overrideWith(_ArchivedPrograms.new),
        currentProgramInstancesProvider.overrideWith(_Runs.new),
        workoutsProvider.overrideWith(_Workouts.new),
        archivedWorkoutsProvider.overrideWith(_ArchivedWorkouts.new),
        personalBestsProvider.overrideWith(_Prs.new),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          router = GoRouter(
            initialLocation: initial,
            routes: [
              ...legacyTrainingRedirects,
              ...trainingBranchRoutes(() => ref.read(trainingViewProvider.notifier).lastUsed()),
              GoRoute(path: '/home', builder: (_, _) => const Text('Home page')),
              GoRoute(path: '/programs/history', builder: (_, _) => const Text('Program history page')),
              GoRoute(path: '/workouts/history', builder: (_, _) => const Text('Workout history page')),
            ],
          );
          return MaterialApp.router(theme: AppTheme.light(), routerConfig: router);
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

String _path(GoRouter router) => router.routerDelegate.currentConfiguration.uri.path;

Future<void> _choose(WidgetTester tester, TrainingView view) async {
  await tester.tap(find.byKey(Key('training_view_${view.segment}')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the switcher shows each view and moves the URL with it', (tester) async {
    final router = await _pump(tester, '/shell/training/programs');
    expect(find.text('Training'), findsOneWidget);
    expect(find.text('ZT 6 Week Program'), findsOneWidget);

    await _choose(tester, TrainingView.workouts);
    expect(_path(router), '/shell/training/workouts');
    expect(find.text('Push Day'), findsOneWidget);
    expect(find.text('ZT 6 Week Program'), findsNothing);

    await _choose(tester, TrainingView.prs);
    expect(_path(router), '/shell/training/prs');
    expect(find.text('Snatch'), findsOneWidget);
  });

  testWidgets('the selected tab follows the route, not just taps', (tester) async {
    final router = await _pump(tester, '/shell/training/programs');
    TabController controller() =>
        tester.widget<TabBar>(find.byKey(const Key('training_view_switcher'))).controller!;
    expect(controller().index, TrainingView.programs.index);

    router.go('/shell/training/prs');
    await tester.pumpAndSettle();
    expect(controller().index, TrainingView.prs.index);
    expect(find.text('Snatch'), findsOneWidget);
  });

  testWidgets('a view keeps its search when you switch away and back', (tester) async {
    await _pump(tester, '/shell/training/programs');
    await tester.enterText(find.byKey(const Key('programs_search')), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No programs match your search.'), findsOneWidget);

    await _choose(tester, TrainingView.workouts);
    await _choose(tester, TrainingView.programs);
    expect(find.text('No programs match your search.'), findsOneWidget);
  });

  testWidgets('history in the app bar follows the view, and PRs has none', (tester) async {
    await _pump(tester, '/shell/training/programs');
    await tester.tap(find.byTooltip('Program history'));
    await tester.pumpAndSettle();
    expect(find.text('Program history page'), findsOneWidget);
  });

  testWidgets('Workouts opens workout history; PRs has no history action', (tester) async {
    await _pump(tester, '/shell/training/workouts');
    expect(find.byTooltip('Program history'), findsNothing);
    await _choose(tester, TrainingView.prs);
    expect(find.byTooltip('Workout history'), findsNothing);
    expect(find.byIcon(Icons.history), findsNothing);
  });

  testWidgets('the bare tab reopens the view used last, which is saved', (tester) async {
    final router = await _pump(tester, '/shell/training');
    expect(_path(router), '/shell/training/programs', reason: 'Programs the first time');

    await _choose(tester, TrainingView.prs);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('training_view'), 'prs');

    router.go('/shell/training');
    await tester.pumpAndSettle();
    expect(_path(router), '/shell/training/prs');
  });

  testWidgets('after a restart, opening Training goes to the saved view', (tester) async {
    SharedPreferences.setMockInitialValues({'training_view': 'workouts'});
    final router = await _pump(tester, '/home');
    router.go('/shell/training');
    await tester.pumpAndSettle();
    expect(_path(router), '/shell/training/workouts');
  });

  testWidgets('a cold launch straight onto Training waits for the saved view', (tester) async {
    SharedPreferences.setMockInitialValues({'training_view': 'prs'});
    final router = await _pump(tester, '/shell/training');
    expect(_path(router), '/shell/training/prs');
  });

  for (final (old, now) in [
    ('/shell/programs', '/shell/training/programs'),
    ('/shell/workouts', '/shell/training/workouts'),
    ('/shell/prs', '/shell/training/prs'),
    ('/shell/training/nonsense', '/shell/training/programs'),
  ]) {
    testWidgets('$old lands on $now', (tester) async {
      final router = await _pump(tester, old);
      expect(_path(router), now);
    });
  }

  testWidgets('the Archived toggle swaps the list and the search hint', (tester) async {
    await _pump(tester, '/shell/training/programs');
    expect(find.text('Old Block'), findsNothing);

    await tester.tap(find.byKey(const Key('archived_toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Old Block'), findsOneWidget);
    expect(find.text('ZT 6 Week Program'), findsNothing);
    expect(find.text('Search archived programs...'), findsOneWidget);
  });
}
