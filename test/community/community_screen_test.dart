import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/core/utils/owner_name.dart';
import 'package:nomorex/features/community/providers/community_programs_provider.dart';
import 'package:nomorex/features/community/providers/community_workouts_provider.dart';
import 'package:nomorex/features/community/screens/community_screen.dart';
import 'package:nomorex/features/programs/models/program.dart';
import 'package:nomorex/features/programs/models/program_week.dart';
import 'package:nomorex/features/workouts/models/workout.dart';

class _StubCommunityWorkoutsNotifier extends CommunityWorkoutsNotifier {
  _StubCommunityWorkoutsNotifier(this._workouts);
  final List<Workout> _workouts;
  @override
  Future<List<Workout>> build() async => _workouts;
}

class _RecordingCommunityWorkoutsNotifier extends CommunityWorkoutsNotifier {
  _RecordingCommunityWorkoutsNotifier(this.onRefresh);
  final VoidCallback onRefresh;
  @override
  Future<List<Workout>> build() async => const [];
  @override
  Future<void> refresh() async => onRefresh();
}

class _StubCommunityProgramsNotifier extends CommunityProgramsNotifier {
  _StubCommunityProgramsNotifier(this._programs);
  final List<Program> _programs;
  @override
  Future<List<Program>> build() async => _programs;
}

class _RecordingCommunityProgramsNotifier extends CommunityProgramsNotifier {
  _RecordingCommunityProgramsNotifier(this.onRefresh);
  final VoidCallback onRefresh;
  @override
  Future<List<Program>> build() async => const [];
  @override
  Future<void> refresh() async => onRefresh();
}

Workout _workout({
  required String id,
  required String title,
  String? owner,
}) =>
    Workout(
      id: id,
      userId: 'other-user',
      title: title,
      date: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 1),
      workoutGroupId: id,
      isPublic: true,
      ownerDisplayName: owner,
    );

Program _program({
  required String id,
  required String name,
  String? owner,
  int weeks = 1,
}) =>
    Program(
      id: id,
      userId: 'other-user',
      name: name,
      createdAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 1),
      isPublic: true,
      ownerDisplayName: owner,
      weeks: [
        for (var i = 0; i < weeks; i++)
          ProgramWeek(
            id: '$id-w$i',
            programId: id,
            weekNumber: i + 1,
            position: i,
          ),
      ],
    );

Future<void> _pumpCommunity(
  WidgetTester tester, {
  List<Workout> workouts = const [],
  List<Program> programs = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        communityWorkoutsProvider.overrideWith(() => _StubCommunityWorkoutsNotifier(workouts)),
        communityProgramsProvider.overrideWith(() => _StubCommunityProgramsNotifier(programs)),
      ],
      child: const MaterialApp(home: CommunityScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists public workouts attributed to their owner', (tester) async {
    await _pumpCommunity(tester, workouts: [
      _workout(id: 'w1', title: '5x5 Strength', owner: 'BeastModeB'),
      _workout(id: 'w2', title: 'Push Pull Legs', owner: 'BeastModeB'),
    ]);

    expect(find.text('5x5 Strength'), findsOneWidget);
    expect(find.text('Push Pull Legs'), findsOneWidget);
    expect(find.textContaining('by BeastModeB'), findsNWidgets(2));
  });

  testWidgets('an owner with no display name falls back to the anonymous label',
      (tester) async {
    await _pumpCommunity(tester, workouts: [
      _workout(id: 'w1', title: '5x5 Strength'),
    ]);

    expect(find.textContaining('by $kAnonymousOwnerName'), findsOneWidget);
  });

  testWidgets('search filters the workout list by title', (tester) async {
    await _pumpCommunity(tester, workouts: [
      _workout(id: 'w1', title: '5x5 Strength', owner: 'Ann'),
      _workout(id: 'w2', title: 'Push Pull Legs', owner: 'Bob'),
    ]);

    await tester.enterText(find.byKey(const Key('community_search')), '5x5');
    await tester.pumpAndSettle();

    expect(find.text('5x5 Strength'), findsOneWidget);
    expect(find.text('Push Pull Legs'), findsNothing);
  });

  testWidgets('search also matches the author name', (tester) async {
    await _pumpCommunity(tester, workouts: [
      _workout(id: 'w1', title: '5x5 Strength', owner: 'Ann'),
      _workout(id: 'w2', title: 'Push Pull Legs', owner: 'Bob'),
    ]);

    await tester.enterText(find.byKey(const Key('community_search')), 'bob');
    await tester.pumpAndSettle();

    expect(find.text('Push Pull Legs'), findsOneWidget);
    expect(find.text('5x5 Strength'), findsNothing);
  });

  testWidgets('the Programs tab lists public programs with their owner', (tester) async {
    await _pumpCommunity(
      tester,
      programs: [
        _program(id: 'p1', name: 'Squat Block', owner: 'BeastModeB', weeks: 4),
      ],
    );

    // The workouts tab is shown first, so the program is not on screen yet.
    expect(find.text('Squat Block'), findsNothing);

    await tester.tap(find.byKey(const Key('community_tab_programs')));
    await tester.pumpAndSettle();

    expect(find.text('Squat Block'), findsOneWidget);
    expect(find.textContaining('by BeastModeB'), findsOneWidget);
    expect(find.textContaining('4 weeks'), findsOneWidget);
  });

  testWidgets('each tab has its own empty state', (tester) async {
    await _pumpCommunity(tester);

    expect(find.text('No public workouts yet.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('community_tab_programs')));
    await tester.pumpAndSettle();

    expect(find.text('No public programs yet.'), findsOneWidget);
  });

  testWidgets('tapping the refresh icon refreshes both lists', (tester) async {
    var workoutsRefreshed = false;
    var programsRefreshed = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          communityWorkoutsProvider.overrideWith(
            () => _RecordingCommunityWorkoutsNotifier(() => workoutsRefreshed = true),
          ),
          communityProgramsProvider.overrideWith(
            () => _RecordingCommunityProgramsNotifier(() => programsRefreshed = true),
          ),
        ],
        child: const MaterialApp(home: CommunityScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    expect(workoutsRefreshed, isTrue);
    expect(programsRefreshed, isTrue);
  });
}
