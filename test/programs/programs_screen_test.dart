import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/shell/nav_section.dart';
import 'package:nomorex/features/training/screens/training_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:nomorex/core/constants/app_constants.dart';
import 'package:nomorex/features/programs/models/program.dart';
import 'package:nomorex/features/programs/models/program_day.dart';
import 'package:nomorex/features/programs/models/program_week.dart';
import 'package:nomorex/features/programs/models/program_instance.dart';
import 'package:nomorex/features/programs/providers/program_instances_list_provider.dart';
import 'package:nomorex/features/programs/utils/program_stats.dart';
import 'package:nomorex/features/programs/providers/programs_provider.dart';
import 'package:nomorex/features/programs/screens/programs_view.dart';
import 'package:nomorex/shared/widgets/archived_pill.dart';
import 'package:nomorex/shared/widgets/dashboard_empty_state_card.dart';
import 'package:nomorex/features/ai/models/ai_import_limits.dart';
import 'package:nomorex/features/ai/providers/ai_import_intake_provider.dart';
import 'package:nomorex/features/programs/providers/finished_program_instances_provider.dart';
import 'package:nomorex/features/ai/core/ai_key_store.dart';
import '../ai/core/ai_fakes.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubProgramsNotifier extends ProgramsNotifier {
  _StubProgramsNotifier(this._programs);
  final List<Program> _programs;
  @override
  Future<List<Program>> build() async => _programs;
}

class _EmptyProgramInstancesNotifier extends CurrentProgramInstancesNotifier {
  @override
  Future<List<ProgramInstance>> build() async => [];
}

class _StubRunsNotifier extends CurrentProgramInstancesNotifier {
  _StubRunsNotifier(this._runs);
  final List<ProgramInstance> _runs;
  @override
  Future<List<ProgramInstance>> build() async => _runs;
}

class _RecordingProgramsNotifier extends ProgramsNotifier {
  _RecordingProgramsNotifier(this.onRefresh);
  final VoidCallback onRefresh;
  @override
  Future<List<Program>> build() async => const [];
  @override
  Future<void> refresh() async => onRefresh();
}

class _StubArchivedProgramsNotifier extends ArchivedProgramsNotifier {
  _StubArchivedProgramsNotifier(this._programs);
  final List<Program> _programs;
  @override
  Future<List<Program>> build() async => _programs;
}

class _RecordingArchivedProgramsNotifier extends ArchivedProgramsNotifier {
  _RecordingArchivedProgramsNotifier(this.onRefresh);
  final VoidCallback onRefresh;
  @override
  Future<List<Program>> build() async => const [];
  @override
  Future<void> refresh() async => onRefresh();
}

/// Records archive and restore calls; [failArchive] makes archiving throw.
class _ArchivingProgramsNotifier extends ProgramsNotifier {
  _ArchivingProgramsNotifier(this._programs, {this.failArchive = false});
  final List<Program> _programs;
  final bool failArchive;
  final archived = <String>[];
  final restored = <String>[];
  @override
  Future<List<Program>> build() async => [for (final p in _programs) if (!archived.contains(p.id)) p];
  @override
  Future<void> archiveProgram(String id) async {
    if (failArchive) throw Exception('PostgrestException: offline');
    archived.add(id);
    ref.invalidateSelf();
  }

  @override
  Future<void> restoreProgram(String id) async {
    restored.add(id);
    archived.remove(id);
    ref.invalidateSelf();
  }
}

class _StubFinishedRunsNotifier extends FinishedProgramInstancesNotifier {
  _StubFinishedRunsNotifier(this._runs);
  final List<ProgramInstance> _runs;
  @override
  Future<List<ProgramInstance>> build() async => _runs;
}

/// A two-week program whose run started today, so today is Week 1, Day 1:
/// a training day with one workout, unless [restToday].
ProgramInstance _runStartedToday(
  String programId, {
  bool restToday = false,
  String status = 'not_started',
  int daysAgo = 0,
  String? title,
}) {
  final now = DateTime.now();
  return ProgramInstance(
    id: 'run-$programId',
    programId: programId,
    userId: 'u1',
    startedAt: DateTime(now.year, now.month, now.day - daysAgo),
    status: 'active',
    structure: [
      StatsWeek([
        StatsDay(id: '$programId-d1', dayOffset: 0, isRest: restToday),
        StatsDay(id: '$programId-d2', dayOffset: 1, isRest: false),
      ]),
      StatsWeek([StatsDay(id: '$programId-d3', dayOffset: 7, isRest: false)]),
    ],
    workoutStatusByKey: {'$programId-d1': status},
    workoutIdByKey: {'$programId-d1': 'workout-$programId-1'},
    workoutTitleByKey: {'$programId-d1': ?title},
  );
}

/// The Programs view with [programs], [runs] and [finished] runs, imports
/// switched [importEnabled], at [size] (800x600 is the desktop layout).
Future<void> _pumpList(
  WidgetTester tester, {
  required List<Program> programs,
  List<ProgramInstance> runs = const [],
  List<ProgramInstance> finished = const [],
  bool importEnabled = false,
  Size? size,
  GoRouter? router,
  ProgramsNotifier Function()? notifier,
}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  final overrides = [
    programsProvider.overrideWith(notifier ?? () => _StubProgramsNotifier(programs)),
    archivedProgramsProvider.overrideWith(() => _StubArchivedProgramsNotifier(const [])),
    currentProgramInstancesProvider.overrideWith(() => _StubRunsNotifier(runs)),
    finishedProgramInstancesProvider.overrideWith(() => _StubFinishedRunsNotifier(finished)),
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
  ];
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: router != null
          ? MaterialApp.router(routerConfig: router)
          : const MaterialApp(home: Scaffold(body: ProgramsView())),
    ),
  );
  await tester.pumpAndSettle();
}

Program _program(String id, String name, {String? description}) => Program(
  id: id,
  userId: 'u1',
  name: name,
  description: description,
  createdAt: DateTime(2026, 8, 1),
  updatedAt: DateTime(2026, 8, 1),
);

void main() {
  // The AI settings read the provider choice from preferences.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'a program row shows weeks and days a week, never a day count that includes rest days',
    (tester) async {
      ProgramDay day(String id, {bool rest = false}) => ProgramDay(
        id: id,
        programWeekId: 'w1',
        dayNumber: 1,
        title: 'Day',
        position: 0,
        isRestDay: rest,
      );
      final program = Program(
        id: 'p1',
        userId: 'u1',
        name: 'Squat Block',
        createdAt: DateTime(2026, 8, 1),
        updatedAt: DateTime(2026, 8, 1),
        weeks: [
          ProgramWeek(
            id: 'w1',
            programId: 'p1',
            weekNumber: 1,
            position: 0,
            days: [day('d1'), day('d2'), day('d3', rest: true)],
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            programsProvider.overrideWith(
              () => _StubProgramsNotifier([program]),
            ),
            currentProgramInstancesProvider.overrideWith(
              () => _EmptyProgramInstancesNotifier(),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: ProgramsView())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1wk'), findsOneWidget, reason: 'the length is on the tile, once');
      expect(find.text('1 week'), findsNothing);
      expect(find.text('2 days/wk'), findsOneWidget);
      expect(find.text('3 days'), findsNothing);
      expect(find.textContaining('workouts'), findsNothing, reason: 'a template has done nothing yet');
    },
  );

  testWidgets('a run past its last week shows its length and the workouts done so far', (
    tester,
  ) async {
    final program = Program(
      id: 'p1',
      userId: 'u1',
      name: 'Squat Block',
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
    );
    final run = ProgramInstance(
      id: 'run-1',
      programId: 'p1',
      userId: 'u1',
      startedAt: DateTime(2000, 1, 1),
      status: 'active',
      structure: const [
        StatsWeek([
          StatsDay(id: 'd1', dayOffset: 0, isRest: false),
          StatsDay(id: 'd2', dayOffset: 1, isRest: false),
          StatsDay(id: 'd3', dayOffset: 2, isRest: true),
        ]),
        StatsWeek([StatsDay(id: 'd4', dayOffset: 3, isRest: false)]),
      ],
      workoutStatusByKey: const {'d1': 'finished', 'd2': 'finished', 'd4': 'not_started'},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          programsProvider.overrideWith(() => _StubProgramsNotifier([program])),
          currentProgramInstancesProvider.overrideWith(() => _StubRunsNotifier([run])),
        ],
        child: const MaterialApp(home: Scaffold(body: ProgramsView())),
      ),
    );
    await tester.pumpAndSettle();

    // Started long ago, so there's no "Week N of M" status to repeat.
    expect(find.text('2wk'), findsOneWidget);
    expect(find.textContaining('days/wk'), findsNothing, reason: 'days a week is for choosing a program');
    expect(find.text('2 of 3 workouts'), findsOneWidget);
    expect(find.text('4 of 4 days'), findsNothing);
  });

  testWidgets('no programs shows an empty-state card with a create button', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          programsProvider.overrideWith(() => _StubProgramsNotifier(const [])),
          archivedProgramsProvider.overrideWith(
            () => _RecordingArchivedProgramsNotifier(() {}),
          ),
          currentProgramInstancesProvider.overrideWith(
            () => _EmptyProgramInstancesNotifier(),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: ProgramsView())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DashboardEmptyStateCard), findsOneWidget);
    expect(find.text('No programs yet'), findsOneWidget);
    // Wide, New program beside search is the one way to create.
    expect(find.text('Create your first program'), findsNothing);
    expect(find.byKey(const Key('programs_new')), findsOneWidget);
  });

  testWidgets("on a phone, the empty state's link opens the new-program route", (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Scaffold(body: ProgramsView())),
        GoRoute(path: AppConstants.routeProgramNew, builder: (_, _) => const Text('new-program-screen')),
      ],
    );
    await _pumpList(tester, programs: const [], router: router, size: const Size(390, 844));

    await tester.ensureVisible(find.text('Create your first program'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create your first program'));
    await tester.pumpAndSettle();

    expect(find.text('new-program-screen'), findsOneWidget);
  });

  testWidgets('the history icon opens the program history route', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const TrainingScreen(view: TrainingView.programs)),
        GoRoute(
          path: AppConstants.routeProgramHistory,
          builder: (_, _) => const Text('program-history-screen'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          programsProvider.overrideWith(() => _StubProgramsNotifier(const [])),
          archivedProgramsProvider.overrideWith(
            () => _RecordingArchivedProgramsNotifier(() {}),
          ),
          currentProgramInstancesProvider.overrideWith(
            () => _EmptyProgramInstancesNotifier(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Program history'));
    await tester.pumpAndSettle();

    expect(find.text('program-history-screen'), findsOneWidget);
  });

  testWidgets('with nothing archived there is no Archived toggle', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          programsProvider.overrideWith(() => _StubProgramsNotifier(const [])),
          archivedProgramsProvider.overrideWith(
            () => _RecordingArchivedProgramsNotifier(() {}),
          ),
          currentProgramInstancesProvider.overrideWith(
            () => _EmptyProgramInstancesNotifier(),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: ProgramsView())),
      ),
    );
    await tester.pumpAndSettle();

    // Nothing to switch to: the toggle comes back with the first archive.
    expect(find.byKey(const Key('archived_toggle')), findsNothing);
  });

  testWidgets('an archived program row shows the pill, its date and Restore only', (
    tester,
  ) async {
    final archived = Program(
      id: 'p9',
      userId: 'u1',
      name: 'Old Block',
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
      isArchived: true,
      archivedAt: DateTime(2026, 10, 26),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          programsProvider.overrideWith(() => _StubProgramsNotifier([_program('p1', 'Live')])),
          archivedProgramsProvider.overrideWith(() => _StubArchivedProgramsNotifier([archived])),
          currentProgramInstancesProvider.overrideWith(
            () => _EmptyProgramInstancesNotifier(),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: ProgramsView())),
      ),
    );
    await tester.pumpAndSettle();

    // The Archived toggle carries the count.
    expect(
      find.descendant(of: find.byKey(const Key('archived_toggle')), matching: find.text('1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('archived_toggle')));
    await tester.pumpAndSettle();

    expect(find.byType(ArchivedPill), findsOneWidget);
    expect(find.text('Archived Oct 26, 2026'), findsOneWidget);
    expect(find.byKey(const Key('archived_restore')), findsOneWidget);
    // Programs are never hard-deleted, so there's no menu beside Restore.
    expect(find.byKey(const Key('archived_menu')), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
  });

  testWidgets(
    'a long description is clamped to two lines with an ellipsis',
    (tester) async {
      final longDescription = 'A' * 250;
      final programs = [
        _program('p1', 'Long Program', description: longDescription),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            programsProvider.overrideWith(
              () => _StubProgramsNotifier(programs),
            ),
            currentProgramInstancesProvider.overrideWith(
              () => _EmptyProgramInstancesNotifier(),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: ProgramsView())),
        ),
      );
      await tester.pumpAndSettle();

      final text = tester.widget<RichText>(
        find.descendant(of: find.text(longDescription), matching: find.byType(RichText)),
      );
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
    },
  );

  testWidgets('a program with no description shows its days a week, and no placeholder', (tester) async {
    ProgramWeek week(String id, int training) => ProgramWeek(
      id: id,
      programId: 'p1',
      weekNumber: 1,
      position: 0,
      days: [
        for (var i = 0; i < 7; i++)
          ProgramDay(id: '$id-$i', programWeekId: id, dayNumber: i + 1, title: 'Day', position: i, isRestDay: i >= training),
      ],
    );
    final program = Program(
      id: 'p1',
      userId: 'u1',
      name: 'Bare Program',
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
      weeks: [week('w1', 5), week('w2', 5)],
    );
    await _pumpList(tester, programs: [program, _program('p2', 'Empty Program')]);

    expect(find.text('5 days/wk'), findsOneWidget);
    expect(find.text('No Description.'), findsNothing);
    expect(find.textContaining('days/wk'), findsOneWidget, reason: 'the empty program has no training days yet');
  });

  testWidgets('search filters programs by name and by description', (
    tester,
  ) async {
    final programs = [
      _program(
        'p1',
        'Powerlifting Block',
        description: 'Squat, bench, deadlift focus.',
      ),
      _program(
        'p2',
        'Hypertrophy Plan',
        description: 'High volume accessory work.',
      ),
      _program('p3', 'Deload Week', description: null),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          programsProvider.overrideWith(() => _StubProgramsNotifier(programs)),
          currentProgramInstancesProvider.overrideWith(
            () => _EmptyProgramInstancesNotifier(),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: ProgramsView())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Powerlifting Block'), findsOneWidget);
    expect(find.text('Hypertrophy Plan'), findsOneWidget);
    expect(find.text('Deload Week'), findsOneWidget);

    // Matches on name.
    await tester.enterText(find.byType(TextField), 'Hypertrophy');
    await tester.pumpAndSettle();
    expect(find.text('Hypertrophy Plan'), findsOneWidget);
    expect(find.text('Powerlifting Block'), findsNothing);
    expect(find.text('Deload Week'), findsNothing);

    // Matches on description even when the query isn't in the name.
    await tester.enterText(find.byType(TextField), 'deadlift');
    await tester.pumpAndSettle();
    expect(find.text('Powerlifting Block'), findsOneWidget);
    expect(find.text('Hypertrophy Plan'), findsNothing);
    expect(find.text('Deload Week'), findsNothing);

    // No matches shows the search-specific empty state.
    await tester.enterText(find.byType(TextField), 'nonexistent');
    await tester.pumpAndSettle();
    expect(find.text('No programs match "nonexistent".'), findsOneWidget);
  });

  testWidgets('tapping the refresh icon refreshes both lists', (tester) async {
    var activeRefreshed = false;
    var archivedRefreshed = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          programsProvider.overrideWith(
            () => _RecordingProgramsNotifier(() => activeRefreshed = true),
          ),
          archivedProgramsProvider.overrideWith(
            () => _RecordingArchivedProgramsNotifier(() => archivedRefreshed = true),
          ),
          currentProgramInstancesProvider.overrideWith(
            () => _EmptyProgramInstancesNotifier(),
          ),
        ],
        child: const MaterialApp(home: TrainingScreen(view: TrainingView.programs)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    expect(activeRefreshed, isTrue);
    expect(archivedRefreshed, isTrue);
  });

  group('running and library', () {
    testWidgets('a running program leads under Current, with where it is today', (tester) async {
      await _pumpList(
        tester,
        programs: [_program('p1', 'Template'), _program('p2', 'Squat Block')],
        runs: [_runStartedToday('p2')],
      );

      expect(find.text('CURRENT'), findsOneWidget);
      expect(find.text('LIBRARY'), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const Key('programs_running')), matching: find.text('Squat Block')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byKey(const Key('programs_library')), matching: find.text('Template')),
        findsOneWidget,
      );
      expect(find.textContaining('Week 1 of 2'), findsOneWidget);
      // The foot's button says which day; the status doesn't repeat it.
      expect(find.textContaining('Day 1 today'), findsNothing);
      expect(find.byKey(const Key('program_today_p2')), findsOneWidget);
      // The status says which week; the facts don't repeat it.
      expect(find.text('2 weeks'), findsNothing);
      expect(find.text('0 of 3 workouts'), findsOneWidget);
    });

    testWidgets("Today's workout opens today's workout", (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: ProgramsView())),
          GoRoute(path: '/workouts/:id', builder: (_, s) => Text('workout ${s.pathParameters['id']}')),
        ],
      );
      await _pumpList(
        tester,
        programs: [_program('p1', 'Squat Block')],
        runs: [_runStartedToday('p1')],
        router: router,
      );

      await tester.tap(find.byKey(const Key('program_today_p1')));
      await tester.pumpAndSettle();
      expect(find.text('workout workout-p1-1'), findsOneWidget);
    });

    testWidgets("once today's workout is finished the button offers a review", (tester) async {
      await _pumpList(
        tester,
        programs: [_program('p1', 'Squat Block')],
        runs: [_runStartedToday('p1', status: 'finished')],
      );
      expect(find.text("Review today's workout"), findsOneWidget);
    });

    testWidgets('a rest day says so and offers no workout', (tester) async {
      await _pumpList(
        tester,
        programs: [_program('p1', 'Squat Block')],
        runs: [_runStartedToday('p1', restToday: true)],
      );
      expect(find.textContaining('Rest day · next session tomorrow'), findsOneWidget);
      expect(find.byKey(const Key('program_today_p1')), findsNothing);
    });

    testWidgets('with nothing running there are no group headers', (tester) async {
      await _pumpList(tester, programs: [_program('p1', 'Template')]);
      expect(find.text('CURRENT'), findsNothing);
      expect(find.text('LIBRARY'), findsNothing);
    });

    testWidgets('a library program shows when it was last run', (tester) async {
      await _pumpList(
        tester,
        programs: [_program('p1', 'Template')],
        finished: [
          ProgramInstance(
            id: 'old',
            programId: 'p1',
            userId: 'u1',
            startedAt: DateTime(2026, 8, 1),
            completedAt: DateTime(2026, 9, 12),
            status: 'completed',
          ),
        ],
      );
      expect(find.text('Last run Sep 12, 2026'), findsOneWidget);
    });
  });

  group('add a program', () {
    testWidgets('offers Community, and importing while imports are on', (tester) async {
      await _pumpList(tester, programs: [_program('p1', 'Template')], importEnabled: true);
      expect(find.byKey(const Key('programs_add_community')), findsOneWidget);
      expect(find.byKey(const Key('programs_add_import')), findsOneWidget);
    });

    testWidgets('leaves importing out while imports are off', (tester) async {
      await _pumpList(tester, programs: [_program('p1', 'Template')]);
      expect(find.byKey(const Key('programs_add_community')), findsOneWidget);
      expect(find.byKey(const Key('programs_add_import')), findsNothing);
    });

    testWidgets('New program sits beside search on a wide screen only', (tester) async {
      await _pumpList(tester, programs: [_program('p1', 'Template')]);
      expect(find.byKey(const Key('programs_new')), findsOneWidget);

      await _pumpList(tester, programs: [_program('p1', 'Template')], size: const Size(390, 844));
      expect(find.byKey(const Key('programs_new')), findsNothing);
    });

    testWidgets('a running row fits a narrow phone', (tester) async {
      await _pumpList(
        tester,
        programs: [_program('p1', 'ZT 6 Week Positional (Triphasic Training)', description: 'x' * 200)],
        runs: [_runStartedToday('p1')],
        importEnabled: true,
        size: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('row actions', () {
    Future<void> openActions(WidgetTester tester, String id) async {
      await tester.tap(find.byKey(Key('program_actions_$id')));
      await tester.pumpAndSettle();
    }

    testWidgets('the ⋯ button is named for its program', (tester) async {
      await _pumpList(tester, programs: [_program('p1', 'Squat Block')]);
      expect(find.byTooltip('Actions for Squat Block'), findsOneWidget);
    });

    testWidgets('offers Start, Edit and Archive, and no Start while running', (tester) async {
      await _pumpList(
        tester,
        programs: [_program('p1', 'Template'), _program('p2', 'Running')],
        runs: [_runStartedToday('p2')],
      );
      await openActions(tester, 'p1');
      expect(find.text('Start program'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Archive'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      await openActions(tester, 'p2');
      expect(find.text('Start program'), findsNothing);
      expect(find.text('Archive'), findsOneWidget);
    });

    testWidgets('Start program asks for the start date', (tester) async {
      await _pumpList(tester, programs: [_program('p1', 'Template')]);
      await openActions(tester, 'p1');
      await tester.tap(find.text('Start program'));
      await tester.pumpAndSettle();
      expect(find.text('Start date'), findsOneWidget);
    });

    testWidgets('archiving says so and Undo brings it back', (tester) async {
      final notifier = _ArchivingProgramsNotifier([_program('p1', 'Squat Block')]);
      await _pumpList(tester, programs: const [], notifier: () => notifier);

      await openActions(tester, 'p1');
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      expect(notifier.archived, ['p1']);
      expect(find.text('Archived Squat Block'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(notifier.restored, ['p1']);
      expect(find.text('Squat Block'), findsOneWidget);
    });

    testWidgets('a running program asks before archiving, and Cancel keeps it', (tester) async {
      final notifier = _ArchivingProgramsNotifier([_program('p1', 'Squat Block')]);
      await _pumpList(tester, programs: const [], runs: [_runStartedToday('p1')], notifier: () => notifier);

      await openActions(tester, 'p1');
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      expect(find.text('Archive Squat Block?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(notifier.archived, isEmpty);

      await openActions(tester, 'p1');
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('program_archive_confirm')));
      await tester.pumpAndSettle();
      expect(notifier.archived, ['p1']);
    });

    testWidgets('a failed archive says so, never the raw error', (tester) async {
      final notifier = _ArchivingProgramsNotifier([_program('p1', 'Squat Block')], failArchive: true);
      await _pumpList(tester, programs: const [], notifier: () => notifier);

      await openActions(tester, 'p1');
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      expect(find.textContaining("Couldn't archive Squat Block"), findsOneWidget);
      expect(find.textContaining('PostgrestException'), findsNothing);
      expect(find.text('Squat Block'), findsOneWidget);
    });
  });

  group('search', () {
    testWidgets('the clear button empties the search', (tester) async {
      await _pumpList(tester, programs: [_program('p1', 'Squat Block'), _program('p2', 'Bench Block')]);
      expect(find.byKey(const Key('programs_search_clear')), findsNothing);

      await tester.enterText(find.byKey(const Key('programs_search')), 'squat');
      await tester.pumpAndSettle();
      expect(find.text('Bench Block'), findsNothing);

      await tester.tap(find.byKey(const Key('programs_search_clear')));
      await tester.pumpAndSettle();
      expect(find.text('Bench Block'), findsOneWidget);
      expect(find.byKey(const Key('programs_search_clear')), findsNothing);
    });

    testWidgets('no matches names the search and offers to clear it', (tester) async {
      await _pumpList(tester, programs: [_program('p1', 'Squat Block')]);
      await tester.enterText(find.byKey(const Key('programs_search')), 'deadlift');
      await tester.pumpAndSettle();
      expect(find.text('No programs match "deadlift".'), findsOneWidget);

      await tester.tap(find.byKey(const Key('programs_no_results_clear')));
      await tester.pumpAndSettle();
      expect(find.text('Squat Block'), findsOneWidget);
    });
  });

  group('the current program', () {
    Future<void> openActions(WidgetTester tester, String id) async {
      await tester.tap(find.byKey(Key('program_actions_$id')));
      await tester.pumpAndSettle();
    }

    testWidgets('its row opens the run; View program opens the template', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: ProgramsView())),
          GoRoute(path: '/programs/:id', builder: (_, s) => Text('program ${s.pathParameters['id']}')),
          GoRoute(path: '/program-instances/:id', builder: (_, s) => Text('run ${s.pathParameters['id']}')),
        ],
      );
      await _pumpList(tester, programs: [_program('p1', 'Squat Block')], runs: [_runStartedToday('p1')], router: router);
      expect(AppConstants.routeProgramInstanceDetail('x'), '/program-instances/x', reason: 'the route this test stubs');

      await tester.tap(find.text('Squat Block'));
      await tester.pumpAndSettle();
      expect(find.text('run run-p1'), findsOneWidget);

      router.go('/');
      await tester.pumpAndSettle();
      await openActions(tester, 'p1');
      expect(find.text('Start program'), findsNothing);
      await tester.tap(find.text('View program'));
      await tester.pumpAndSettle();
      expect(find.text('program p1'), findsOneWidget);
    });

    testWidgets("today's workout names its session and takes the orange from New program", (tester) async {
      await _pumpList(tester, programs: [_program('p1', 'Squat Block')], runs: [_runStartedToday('p1', title: 'Day 1')]);

      expect(find.text('Today · Day 1'), findsOneWidget);
      final today = tester.widget<FilledButton>(find.byKey(const Key('program_today_p1')));
      final create = tester.widget<FilledButton>(find.byKey(const Key('programs_new')));
      expect(today.style?.backgroundColor, isNull, reason: "the theme's orange fill");
      expect(create.style?.backgroundColor, isNotNull, reason: 'the neutral button');
    });

    testWidgets('once today is done nothing is orange: New program stays neutral while a run is current', (tester) async {
      await _pumpList(tester, programs: [_program('p1', 'Squat Block')], runs: [_runStartedToday('p1', status: 'finished')]);
      final today = tester.widget<FilledButton>(find.byKey(const Key('program_today_p1')));
      final create = tester.widget<FilledButton>(find.byKey(const Key('programs_new')));
      expect(today.style?.backgroundColor, isNotNull);
      expect(create.style?.backgroundColor, isNotNull);
    });

    testWidgets('with no current program, New program has the orange', (tester) async {
      await _pumpList(tester, programs: [_program('p1', 'Template')]);
      final create = tester.widget<FilledButton>(find.byKey(const Key('programs_new')));
      expect(create.style?.backgroundColor, isNull);
    });

    testWidgets('the foot button is named for its program', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpList(tester, programs: [_program('p1', 'Squat Block')], runs: [_runStartedToday('p1', title: 'Day 1')]);
      final named = find.bySemanticsLabel("Today's workout for Squat Block, Day 1");
      expect(named, findsOneWidget);
      expect(tester.getSemantics(named), isSemantics(isButton: true, hasTapAction: true));
      handle.dispose();
    });

    testWidgets('Complete program on the row completes the run after asking', (tester) async {
      await _pumpList(tester, programs: [_program('p1', 'Squat Block')], runs: [_runStartedToday('p1', daysAgo: 30)]);
      await tester.tap(find.byKey(const Key('program_complete_p1')));
      await tester.pumpAndSettle();
      expect(find.text('Complete Squat Block?'), findsOneWidget);
    });

    testWidgets('a run past its last week says its schedule is finished and offers Complete', (tester) async {
      await _pumpList(tester, programs: [_program('p1', 'Squat Block')], runs: [_runStartedToday('p1', daysAgo: 30)]);
      expect(find.textContaining('Schedule finished'), findsOneWidget);
      expect(find.textContaining('In progress'), findsNothing);
      expect(find.byKey(const Key('program_run_status_done')), findsOneWidget);
      // Its next step is on the row, with the page's orange.
      final complete = tester.widget<FilledButton>(find.byKey(const Key('program_complete_p1')));
      expect(complete.style?.backgroundColor, isNull);

      await openActions(tester, 'p1');
      expect(find.text('Complete program'), findsWidgets, reason: 'in the sheet as well as the row');
    });

    testWidgets('a run still under way offers no Complete', (tester) async {
      await _pumpList(tester, programs: [_program('p1', 'Squat Block')], runs: [_runStartedToday('p1')]);
      await openActions(tester, 'p1');
      expect(find.text('Complete program'), findsNothing);
    });

    testWidgets('leaves the description to the program screen', (tester) async {
      await _pumpList(
        tester,
        programs: [_program('p1', 'Squat Block', description: 'Heavy triples.')],
        runs: [_runStartedToday('p1')],
      );
      expect(find.text('Heavy triples.'), findsNothing);
    });
  });

  testWidgets('the library leads with the program run most recently', (tester) async {
    await _pumpList(
      tester,
      programs: [_program('new', 'Newest Program'), _program('old', 'Old Favourite')],
      finished: [
        ProgramInstance(
          id: 'r',
          programId: 'old',
          userId: 'u1',
          startedAt: DateTime(2026, 9, 1),
          completedAt: DateTime(2026, 10, 1),
          status: 'completed',
        ),
      ],
    );
    final oldTop = tester.getTopLeft(find.text('Old Favourite')).dy;
    final newTop = tester.getTopLeft(find.text('Newest Program')).dy;
    expect(oldTop, lessThan(newTop));
  });

  group('screen readers', () {
    testWidgets('a program row is one button named by what it says, with ⋯ its own control', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpList(tester, programs: [_program('p1', 'Squat Block')]);

      final row = tester.getSemantics(find.text('Squat Block'));
      expect(row, isSemantics(isButton: true, hasTapAction: true));
      expect(row.label, contains('Squat Block'));
      expect(row.label, isNot(contains('Actions for')));
      expect(tester.getSemantics(find.byTooltip('Actions for Squat Block')), isSemantics(isButton: true, hasTapAction: true));
      handle.dispose();
    });

    testWidgets('group labels are headings', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpList(tester, programs: [_program('p1', 'Template'), _program('p2', 'Squat Block')], runs: [_runStartedToday('p2')]);
      expect(tester.getSemantics(find.text('CURRENT')), isSemantics(isHeader: true));
      expect(tester.getSemantics(find.text('LIBRARY')), isSemantics(isHeader: true));
      handle.dispose();
    });
  });
}
