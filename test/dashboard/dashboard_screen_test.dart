import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/dashboard/screens/dashboard_screen.dart';
import 'package:nomorex/features/personal_bests/models/personal_best.dart';
import 'package:nomorex/features/personal_bests/providers/personal_bests_provider.dart';
import 'package:nomorex/features/programs/models/program_instance.dart';
import 'package:nomorex/features/programs/providers/program_instances_list_provider.dart';
import 'package:nomorex/features/workouts/models/workout.dart';
import 'package:nomorex/features/workouts/providers/finished_workouts_provider.dart';
import 'package:nomorex/features/workouts/providers/in_progress_workouts_provider.dart';

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

class _RecordingPersonalBestsNotifier extends PersonalBestsNotifier {
  _RecordingPersonalBestsNotifier(this.onRefresh);
  final VoidCallback onRefresh;
  @override
  Future<List<PersonalBest>> build() async => [];
  @override
  Future<void> refresh() async => onRefresh();
}

class _RecordingProgramInstancesNotifier extends CurrentProgramInstancesNotifier {
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

void main() {
  testWidgets('shows empty state when no programs are in progress', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalBestsProvider.overrideWith(() => _StubPersonalBestsNotifier()),
          currentProgramInstancesProvider.overrideWith(() => _EmptyProgramInstancesNotifier()),
          inProgressWorkoutsProvider.overrideWith(() => _EmptyInProgressWorkoutsNotifier()),
          finishedWorkoutsProvider.overrideWith(() => _EmptyFinishedWorkoutsNotifier()),
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
          personalBestsProvider.overrideWith(() => _StubPersonalBestsNotifier()),
          currentProgramInstancesProvider
              .overrideWith(() => _StubProgramInstancesNotifier([instance])),
          inProgressWorkoutsProvider.overrideWith(() => _EmptyInProgressWorkoutsNotifier()),
          finishedWorkoutsProvider.overrideWith(() => _EmptyFinishedWorkoutsNotifier()),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Strong Like Bull'), findsOneWidget);
    expect(find.textContaining('In progress'), findsOneWidget);
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
          personalBestsProvider.overrideWith(() => _StubPersonalBestsNotifier()),
          currentProgramInstancesProvider
              .overrideWith(() => _StubProgramInstancesNotifier([instance])),
          inProgressWorkoutsProvider.overrideWith(() => _EmptyInProgressWorkoutsNotifier()),
          finishedWorkoutsProvider.overrideWith(() => _EmptyFinishedWorkoutsNotifier()),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Upcoming'), findsOneWidget);
  });

  testWidgets('shows empty state when no workouts are in progress', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalBestsProvider.overrideWith(() => _StubPersonalBestsNotifier()),
          currentProgramInstancesProvider.overrideWith(() => _EmptyProgramInstancesNotifier()),
          inProgressWorkoutsProvider.overrideWith(() => _EmptyInProgressWorkoutsNotifier()),
          finishedWorkoutsProvider.overrideWith(() => _EmptyFinishedWorkoutsNotifier()),
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
          personalBestsProvider.overrideWith(() => _StubPersonalBestsNotifier()),
          currentProgramInstancesProvider.overrideWith(() => _EmptyProgramInstancesNotifier()),
          inProgressWorkoutsProvider.overrideWith(() => _StubInProgressWorkoutsNotifier([workout])),
          finishedWorkoutsProvider.overrideWith(() => _EmptyFinishedWorkoutsNotifier()),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Push Day'), findsOneWidget);
    expect(find.textContaining('In progress — started'), findsOneWidget);
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
          personalBestsProvider.overrideWith(() => _StubPersonalBestsNotifier()),
          currentProgramInstancesProvider.overrideWith(() => _EmptyProgramInstancesNotifier()),
          inProgressWorkoutsProvider.overrideWith(() => _StubInProgressWorkoutsNotifier([workout])),
          finishedWorkoutsProvider.overrideWith(() => _EmptyFinishedWorkoutsNotifier()),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Push Day'), findsOneWidget);
    expect(find.textContaining('Paused — started'), findsOneWidget);
  });

  testWidgets('shows empty state when no workouts have been completed', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalBestsProvider.overrideWith(() => _StubPersonalBestsNotifier()),
          currentProgramInstancesProvider.overrideWith(() => _EmptyProgramInstancesNotifier()),
          inProgressWorkoutsProvider.overrideWith(() => _EmptyInProgressWorkoutsNotifier()),
          finishedWorkoutsProvider.overrideWith(() => _EmptyFinishedWorkoutsNotifier()),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No completed workouts yet.'), findsOneWidget);
  });

  testWidgets('shows up to 5 recent workouts, most recently completed first', (tester) async {
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
          personalBestsProvider.overrideWith(() => _StubPersonalBestsNotifier()),
          currentProgramInstancesProvider.overrideWith(() => _EmptyProgramInstancesNotifier()),
          inProgressWorkoutsProvider.overrideWith(() => _EmptyInProgressWorkoutsNotifier()),
          finishedWorkoutsProvider.overrideWith(() => _StubFinishedWorkoutsNotifier(newestFirst)),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Workout 5'), findsOneWidget);
    expect(find.text('Workout 1'), findsOneWidget);
    expect(find.text('Workout 0'), findsNothing);
  });

  testWidgets('tapping the refresh icon refreshes all four data sources', (tester) async {
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
            () => _RecordingProgramInstancesNotifier(() => instancesRefreshed = true),
          ),
          inProgressWorkoutsProvider.overrideWith(
            () => _RecordingInProgressWorkoutsNotifier(() => workoutsRefreshed = true),
          ),
          finishedWorkoutsProvider.overrideWith(
            () => _RecordingFinishedWorkoutsNotifier(() => finishedWorkoutsRefreshed = true),
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
}
