import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nomorex/core/utils/copy_errors.dart';
import 'package:nomorex/core/utils/owner_name.dart';
import 'package:nomorex/features/auth/providers/auth_provider.dart';
import 'package:nomorex/features/community/providers/community_program_detail_provider.dart';
import 'package:nomorex/features/community/screens/community_program_detail_screen.dart';
import 'package:nomorex/features/programs/models/program.dart';
import 'package:nomorex/features/programs/models/program_day.dart';
import 'package:nomorex/features/programs/models/program_exercise.dart';
import 'package:nomorex/features/programs/models/program_week.dart';
import 'package:nomorex/features/programs/providers/program_copy_count_provider.dart';
import 'package:nomorex/features/programs/providers/programs_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _StubCommunityProgramDetailNotifier extends CommunityProgramDetailNotifier {
  _StubCommunityProgramDetailNotifier(this._program);
  final Program _program;
  @override
  Future<Program> build(String programId) async => _program;
}

/// Records save/start calls instead of hitting the copy_program RPC.
class _RecordingProgramsNotifier extends ProgramsNotifier {
  _RecordingProgramsNotifier({this.onSave});
  final Future<({String programId, String? instanceId})> Function(DateTime? startDate)? onSave;
  final calls = <({String sourceId, DateTime? startDate})>[];

  @override
  Future<List<Program>> build() async => const [];

  @override
  Future<({String programId, String? instanceId})> saveCommunityProgram(
    String sourceProgramId, {
    DateTime? startDate,
  }) async {
    calls.add((sourceId: sourceProgramId, startDate: startDate));
    if (onSave != null) return onSave!(startDate);
    return (programId: 'copy-1', instanceId: startDate == null ? null : 'run-1');
  }
}

User _user(String id) => User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
    );

Program _program({String? owner}) => Program(
      id: 'p1',
      userId: 'other-user',
      name: 'Squat Block',
      description: 'Four weeks of squatting.',
      createdAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 1),
      isPublic: true,
      ownerDisplayName: owner,
      weeks: [
        ProgramWeek(
          id: 'wk1',
          programId: 'p1',
          weekNumber: 1,
          position: 0,
          label: 'Accumulation',
          days: [
            const ProgramDay(
              id: 'd1',
              programWeekId: 'wk1',
              dayNumber: 1,
              title: 'Day 1',
              position: 0,
              exercises: [
                ProgramExercise(
                  id: 'pe1',
                  programDayId: 'd1',
                  exerciseId: 'e1',
                  exerciseName: 'Back Squat',
                  position: 0,
                ),
              ],
            ),
            const ProgramDay(
              id: 'd2',
              programWeekId: 'wk1',
              dayNumber: 2,
              title: 'Day 2',
              position: 1,
              isRestDay: true,
            ),
          ],
        ),
      ],
    );

Future<void> _pump(
  WidgetTester tester,
  Program program, {
  String viewerId = 'viewer',
  int copyCount = 0,
  _RecordingProgramsNotifier? programsNotifier,
  GoRouter? router,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        communityProgramDetailProvider('p1')
            .overrideWith(() => _StubCommunityProgramDetailNotifier(program)),
        currentAuthUserProvider.overrideWithValue(_user(viewerId)),
        programCopyCountProvider('p1').overrideWith((ref) async => copyCount),
        programsProvider.overrideWith(() => programsNotifier ?? _RecordingProgramsNotifier()),
      ],
      // Always under a GoRouter, as in the app: the save/start actions
      // capture it up front for their SnackBar actions.
      child: MaterialApp.router(
        routerConfig: router ??
            GoRouter(
              initialLocation: '/community/programs/p1',
              routes: [
                GoRoute(
                  path: '/community/programs/p1',
                  builder: (_, _) => const CommunityProgramDetailScreen(programId: 'p1'),
                ),
              ],
            ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

GoRouter _routerWithDestinations() => GoRouter(
      initialLocation: '/community/programs/p1',
      routes: [
        GoRoute(
          path: '/community/programs/p1',
          builder: (_, _) => const CommunityProgramDetailScreen(programId: 'p1'),
        ),
        GoRoute(
          path: '/programs/:id',
          builder: (_, state) => Text('program:${state.pathParameters['id']}'),
        ),
        GoRoute(
          path: '/program-instances/:id',
          builder: (_, state) => Text('run:${state.pathParameters['id']}'),
        ),
      ],
    );

void main() {
  testWidgets('shows the program, its owner, and its weeks', (tester) async {
    await _pump(tester, _program(owner: 'BeastModeB'));

    expect(find.text('Squat Block'), findsOneWidget);
    expect(find.textContaining('by BeastModeB'), findsOneWidget);
    expect(find.textContaining('1 week'), findsOneWidget);
    expect(find.text('Four weeks of squatting.'), findsOneWidget);
    expect(find.text('Week 1 — Accumulation'), findsOneWidget);
    expect(find.text('Day 1'), findsOneWidget);
    expect(find.text('Day 2'), findsOneWidget);
  });

  testWidgets('falls back to the anonymous label when the owner has no name',
      (tester) async {
    await _pump(tester, _program());

    expect(find.textContaining('by $kAnonymousOwnerName'), findsOneWidget);
  });

  testWidgets('the program itself stays read-only: no edit action', (tester) async {
    await _pump(tester, _program(owner: 'BeastModeB'));

    expect(find.text('Read only'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });

  testWidgets('a rest day is summarized and not tappable', (tester) async {
    await _pump(tester, _program(owner: 'BeastModeB'));

    expect(find.text('Rest day'), findsOneWidget);
    // Only the day that has exercises offers a chevron into it.
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  group('save / start (FR-002, FR-015, FR-018)', () {
    testWidgets("offers Start and Save on another user's program", (tester) async {
      await _pump(tester, _program(owner: 'BeastModeB'));

      expect(find.byKey(const Key('community_program_start')), findsOneWidget);
      expect(find.byKey(const Key('community_program_save')), findsOneWidget);
      expect(find.byKey(const Key('community_program_saved_hint')), findsNothing);
    });

    testWidgets('offers neither on your own program', (tester) async {
      await _pump(tester, _program(owner: 'BeastModeB'), viewerId: 'other-user');

      expect(find.byKey(const Key('community_program_start')), findsNothing);
      expect(find.byKey(const Key('community_program_save')), findsNothing);
    });

    testWidgets('says when the viewer already has a copy', (tester) async {
      await _pump(tester, _program(owner: 'BeastModeB'), copyCount: 1);

      expect(find.byKey(const Key('community_program_saved_hint')), findsOneWidget);
      expect(find.text("You've saved this once"), findsOneWidget);
    });

    testWidgets('Save copies without starting, confirms, and View opens the copy',
        (tester) async {
      final notifier = _RecordingProgramsNotifier();
      await _pump(
        tester,
        _program(owner: 'BeastModeB'),
        programsNotifier: notifier,
        router: _routerWithDestinations(),
      );

      await tester.ensureVisible(find.byKey(const Key('community_program_save')));
      await tester.tap(find.byKey(const Key('community_program_save')));
      await tester.pumpAndSettle();

      expect(notifier.calls.single.startDate, isNull);
      expect(find.text('Saved to your programs'), findsOneWidget);

      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      expect(find.text('program:copy-1'), findsOneWidget);
    });

    testWidgets('leaving the screen closes its "Saved" SnackBar', (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.push('/community/programs/p1'),
                child: const Text('open'),
              ),
            ),
          ),
          GoRoute(
            path: '/community/programs/p1',
            builder: (_, _) => const CommunityProgramDetailScreen(programId: 'p1'),
          ),
          GoRoute(
            path: '/programs/:id',
            builder: (_, state) => Text('program:${state.pathParameters['id']}'),
          ),
        ],
      );
      await _pump(tester, _program(owner: 'BeastModeB'), router: router);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('community_program_save')));
      await tester.tap(find.byKey(const Key('community_program_save')));
      await tester.pumpAndSettle();

      expect(find.text('Saved to your programs'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();

      expect(find.text('open'), findsOneWidget);
      expect(find.text('Saved to your programs'), findsNothing);
    });

    testWidgets('Start asks for a date, then starts a copy and opens the run',
        (tester) async {
      final notifier = _RecordingProgramsNotifier();
      await _pump(
        tester,
        _program(owner: 'BeastModeB'),
        programsNotifier: notifier,
        router: _routerWithDestinations(),
      );

      await tester.ensureVisible(find.byKey(const Key('community_program_start')));
      await tester.tap(find.byKey(const Key('community_program_start')));
      await tester.pumpAndSettle();
      expect(find.text('Start date'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Start'));
      await tester.pumpAndSettle();

      expect(notifier.calls.single.startDate, isNotNull);
      expect(find.text('run:run-1'), findsOneWidget);
    });

    testWidgets('cancelling the date dialog copies nothing', (tester) async {
      final notifier = _RecordingProgramsNotifier();
      await _pump(tester, _program(owner: 'BeastModeB'), programsNotifier: notifier);

      await tester.ensureVisible(find.byKey(const Key('community_program_start')));
      await tester.tap(find.byKey(const Key('community_program_start')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(notifier.calls, isEmpty);
    });

    testWidgets('both buttons are disabled while a copy is in flight', (tester) async {
      final pending = Completer<({String programId, String? instanceId})>();
      await _pump(
        tester,
        _program(owner: 'BeastModeB'),
        programsNotifier: _RecordingProgramsNotifier(onSave: (_) => pending.future),
      );

      await tester.ensureVisible(find.byKey(const Key('community_program_save')));
      await tester.tap(find.byKey(const Key('community_program_save')));
      await tester.pump();

      for (final key in ['community_program_start', 'community_program_save']) {
        expect(tester.widget<ButtonStyleButton>(find.byKey(Key(key))).onPressed, isNull);
      }

      pending.complete((programId: 'copy-1', instanceId: null));
      await tester.pumpAndSettle();
    });

    testWidgets('an archived source explains it is no longer available', (tester) async {
      const error = PostgrestException(message: 'archived: program p1', code: 'P0001');
      await _pump(
        tester,
        _program(owner: 'BeastModeB'),
        programsNotifier: _RecordingProgramsNotifier(onSave: (_) => Future.error(error)),
      );

      await tester.ensureVisible(find.byKey(const Key('community_program_save')));
      await tester.tap(find.byKey(const Key('community_program_save')));
      await tester.pumpAndSettle();

      expect(find.text(copyErrorMessage(error)), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
