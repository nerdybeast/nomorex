import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nomorex/core/constants/app_constants.dart';
import 'package:nomorex/core/theme/app_theme.dart';
import 'package:nomorex/features/programs/models/program.dart';
import 'package:nomorex/features/programs/models/program_instance.dart';
import 'package:nomorex/features/programs/providers/finished_program_instances_provider.dart';
import 'package:nomorex/features/programs/providers/program_detail_provider.dart';
import 'package:nomorex/features/programs/providers/program_instance_detail_provider.dart';
import 'package:nomorex/features/programs/providers/program_instance_workouts_provider.dart';
import 'package:nomorex/features/programs/providers/program_instances_provider.dart';
import 'package:nomorex/features/programs/screens/program_history_screen.dart';
import 'package:nomorex/features/programs/screens/program_instance_detail_screen.dart';

class _StubFinishedNotifier extends FinishedProgramInstancesNotifier {
  _StubFinishedNotifier(this._instances);
  final List<ProgramInstance> _instances;
  @override
  Future<List<ProgramInstance>> build() async => _instances;
}

class _StubInstanceNotifier extends ProgramInstanceDetailNotifier {
  _StubInstanceNotifier(this._instance);
  final ProgramInstance _instance;
  @override
  Future<ProgramInstance> build(String instanceId) async => _instance;
}

class _StubProgramDetailNotifier extends ProgramDetailNotifier {
  @override
  Future<Program> build(String programId) async => Program(
        id: 'p1',
        userId: 'u1',
        name: 'Block',
        createdAt: DateTime(2026, 8, 1),
        updatedAt: DateTime(2026, 8, 1),
      );
}

class _EmptyInstanceWorkoutsNotifier extends ProgramInstanceWorkoutsNotifier {
  @override
  Future<Map<String, String>> build(String instanceId) async => const {};
}

class _RecordingInstancesNotifier extends ProgramInstancesNotifier {
  _RecordingInstancesNotifier(this.calls);
  final List<String> calls;
  @override
  void build() {}
  @override
  Future<void> completeProgramInstance(String id) async => calls.add('complete:$id');
  @override
  Future<void> abandonProgramInstance(String id) async => calls.add('abandon:$id');
}

ProgramInstance _instance(
  String id,
  String name, {
  String status = 'completed',
  DateTime? completedAt,
}) =>
    ProgramInstance(
      id: id,
      programId: 'p1',
      userId: 'u1',
      startedAt: DateTime(2026, 8, 1),
      status: status,
      programName: name,
      completedAt: completedAt,
    );

void main() {
  test('ProgramInstance.fromJson reads completed_at', () {
    final json = {
      'id': 'i1',
      'program_id': 'p1',
      'user_id': 'u1',
      'started_at': '2026-08-01',
      'status': 'completed',
      'completed_at': '2026-09-01T12:00:00Z',
    };
    final instance = ProgramInstance.fromJson(json);
    expect(instance.completedAt, DateTime.utc(2026, 9, 1, 12));
    expect(instance.isActive, isFalse);
    expect(ProgramInstance.fromJson({...json, 'completed_at': null}).completedAt, isNull);
  });

  group('ProgramHistoryScreen', () {
    Future<void> pump(WidgetTester tester, List<ProgramInstance> items) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            finishedProgramInstancesProvider.overrideWith(() => _StubFinishedNotifier(items)),
          ],
          child: const MaterialApp(home: ProgramHistoryScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows an empty state', (tester) async {
      await pump(tester, const []);
      expect(find.text("You haven't completed any programs yet."), findsOneWidget);
    });

    testWidgets('lists completed and abandoned runs in the order given', (tester) async {
      await pump(tester, [
        _instance('i1', 'Newer Block', completedAt: DateTime(2026, 10, 1)),
        _instance('i2', 'Older Block', status: 'abandoned', completedAt: DateTime(2026, 9, 1)),
      ]);

      expect(find.text('Newer Block'), findsOneWidget);
      expect(find.textContaining('Abandoned'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Newer Block')).dy,
        lessThan(tester.getTopLeft(find.text('Older Block')).dy),
      );
    });

    testWidgets('tapping a run opens its detail route', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const ProgramHistoryScreen()),
          GoRoute(
            path: '/program-instances/:id',
            builder: (_, state) => Text('detail-${state.pathParameters['id']}'),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            finishedProgramInstancesProvider.overrideWith(
              () => _StubFinishedNotifier([_instance('i1', 'Block', completedAt: DateTime(2026, 10, 1))]),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Block'));
      await tester.pumpAndSettle();
      expect(find.text('detail-i1'), findsOneWidget);
      expect(AppConstants.routeProgramInstanceDetail('i1'), '/program-instances/i1');
    });
  });

  group('ProgramInstanceDetailScreen end actions', () {
    Future<List<String>> pump(WidgetTester tester, ProgramInstance instance) async {
      final calls = <String>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            programInstanceDetailProvider('run-1').overrideWith(() => _StubInstanceNotifier(instance)),
            programDetailProvider('p1').overrideWith(() => _StubProgramDetailNotifier()),
            programInstanceWorkoutsProvider('run-1')
                .overrideWith(() => _EmptyInstanceWorkoutsNotifier()),
            programInstancesProvider.overrideWith(() => _RecordingInstancesNotifier(calls)),
          ],
          // The real theme: it makes FilledButton full-width, which is what
          // exposed an unbounded-width layout error a bare MaterialApp hides.
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ProgramInstanceDetailScreen(instanceId: 'run-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return calls;
    }

    testWidgets('an active run can be completed after confirming', (tester) async {
      final calls = await pump(tester, _instance('run-1', 'Block', status: 'active'));

      await tester.tap(find.byKey(const Key('program_instance_complete')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Complete').last);
      await tester.pumpAndSettle();

      expect(calls, ['complete:run-1']);
    });

    testWidgets('cancelling the dialog does nothing', (tester) async {
      final calls = await pump(tester, _instance('run-1', 'Block', status: 'active'));

      await tester.tap(find.byKey(const Key('program_instance_abandon')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(calls, isEmpty);
    });

    testWidgets('an active run can be abandoned after confirming', (tester) async {
      final calls = await pump(tester, _instance('run-1', 'Block', status: 'active'));

      await tester.tap(find.byKey(const Key('program_instance_abandon')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abandon').last);
      await tester.pumpAndSettle();

      expect(calls, ['abandon:run-1']);
    });

    testWidgets('an ended run shows its status and no actions', (tester) async {
      await pump(
        tester,
        _instance('run-1', 'Block', completedAt: DateTime(2026, 10, 1)),
      );

      expect(find.textContaining('Completed'), findsOneWidget);
      expect(find.byKey(const Key('program_instance_complete')), findsNothing);
      expect(find.byKey(const Key('program_instance_abandon')), findsNothing);
    });
  });
}
