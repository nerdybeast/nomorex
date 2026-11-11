import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nomorex/features/ai/models/ai_import_result.dart';
import 'package:nomorex/features/ai/providers/ai_import_review_provider.dart';
import 'package:nomorex/features/ai/screens/ai_import_review_screen.dart';
import 'package:nomorex/features/ai/utils/genkit_call.dart';
import 'package:nomorex/features/exercises/models/exercise.dart';
import 'package:nomorex/features/exercises/providers/exercises_provider.dart';

import 'ai_import_job_fakes.dart';
import 'ai_import_review_fixtures.dart';

/// What the fake server was asked to do.
class ReviewServer {
  ReviewServer(this.review);

  AiImportReview? review;
  final List<Map<String, dynamic>> accepted = [];
  final List<(String, String)> reruns = [];
  Object? acceptError;
  Object? rerunError;
}

class FakeReviewNotifier extends AiImportReviewNotifier {
  FakeReviewNotifier(this.server);
  final ReviewServer server;

  @override
  Future<AiImportReview?> fetchReview(String jobId) async => server.review;

  @override
  Future<AcceptedImport> acceptImport(String jobId, Map<String, dynamic> reviewed, String today) async {
    if (server.acceptError case final e?) throw e;
    server.accepted.add(reviewed);
    return server.review!.type == 'program'
        ? (workoutId: null, programId: 'p-new')
        : (workoutId: 'w-new', programId: null);
  }

  @override
  Future<String> startImport(String importId, String type) async {
    if (server.rerunError case final e?) throw e;
    server.reruns.add((importId, type));
    return 'j2';
  }
}

class FakeExercises extends ExercisesNotifier {
  @override
  Future<List<Exercise>> build() async => const [
    Exercise(id: 'ex-bp', name: 'Bench Press', isPredefined: true),
    Exercise(id: 'ex-bs', name: 'Back Squat', isPredefined: true),
    Exercise(id: 'ex-ps', name: 'Paused Back Squat', isPredefined: false, userId: 'u1'),
  ];
}

AiImportReview readyReview(Map<String, dynamic> payload, {String status = 'ready'}) => AiImportReview(
  jobId: 'j1',
  importId: 'import-j1',
  status: status,
  type: payload['type'] as String,
  result: status == 'ready' ? AiImportResult.fromJson(payload) : null,
  acceptedWorkoutId: status == 'accepted' ? 'w-old' : null,
);

void main() {
  late ReviewServer server;
  late FakeJobServer jobs;

  Future<void> pump(WidgetTester tester, AiImportReview? review, {Size size = const Size(900, 3200)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    server = ReviewServer(review);
    jobs = FakeJobServer()..jobs['u1'] = [testJob('j1', 'ready')];

    final router = GoRouter(
      initialLocation: '/shell/home',
      routes: [
        GoRoute(
          path: '/shell/home',
          builder: (_, _) => const Scaffold(body: Text('Home screen')),
        ),
        GoRoute(
          path: '/ai-import/review/:jobId',
          builder: (_, s) => AiImportReviewScreen(jobId: s.pathParameters['jobId']!),
        ),
        GoRoute(
          path: '/workouts/:id',
          builder: (_, s) => Scaffold(body: Text('Workout ${s.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/programs/:id',
          builder: (_, s) => Scaffold(body: Text('Program ${s.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...jobOverrides(jobs, FakeSubscriber()),
          aiImportReviewProvider('j1').overrideWith(() => FakeReviewNotifier(server)),
          exercisesProvider.overrideWith(FakeExercises.new),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.push('/ai-import/review/j1');
    await tester.pumpAndSettle();
  }

  FilledButton acceptButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byKey(const Key('ai_import_review_accept')));

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('a workout', () {
    testWidgets('previews everything that was read', (tester) async {
      await pump(tester, readyReview(workoutResult()));

      expect(find.text('Read as a workout · 4 exercises'), findsOneWidget);
      expect(find.text('Lower body A'), findsOneWidget, reason: 'the title field');
      expect(find.text('Front Squat'), findsOneWidget);
      expect(find.textContaining('3 × 3 @ 70–72.5% of 2 Hang Clean + 1 Jerk'), findsOneWidget);
      expect(find.textContaining('4 × 6 @ 225 lbs · RPE 7–8'), findsOneWidget);
      expect(find.textContaining('100 (unit?)'), findsOneWidget);
      expect(find.textContaining('2 × 10 · choose load'), findsOneWidget);
      expect(find.text('light by feel'), findsOneWidget);
      expect(find.text('Best guess: Bench Press. Check it.'), findsWidgets);
    });

    testWidgets('shows flagged notes and leaves unread values visibly empty', (tester) async {
      await pump(tester, readyReview(workoutResult()));

      expect(find.text("COULDN'T BE STRUCTURED"), findsOneWidget);
      expect(find.text('Walking lunge 3 x 12 light by feel'), findsOneWidget);
      expect(find.text('WORKOUT, DAY 1, LOWER BODY A, WALKING LUNGE'), findsOneWidget);
      expect(find.textContaining('5 × — @ 75%'), findsOneWidget);
      expect(find.text("Couldn't read: reps"), findsOneWidget);
      expect(find.text('Reps as printed: 2+l'), findsOneWidget);
    });

    testWidgets('warns about a handwritten import beside Accept', (tester) async {
      await pump(tester, readyReview(workoutResult()));
      expect(find.byKey(const Key('ai_import_review_handwritten')), findsOneWidget);
    });

    testWidgets('Accept stays disabled until the unit is chosen, then saves in kg', (tester) async {
      await pump(tester, readyReview(workoutResult()));

      expect(acceptButton(tester).onPressed, isNull);
      expect(find.byKey(const Key('ai_import_review_unit_hint')), findsOneWidget);

      await tester.tap(find.descendant(of: find.byKey(const Key('ai_import_review_unit')), matching: find.text('lbs')));
      await tester.pumpAndSettle();
      expect(acceptButton(tester).onPressed, isNotNull);
      expect(find.textContaining('100 lbs'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('ai_import_review_title')), 'Leg day');
      await tapKey(tester, 'ai_import_review_accept');

      final saved = server.accepted.single;
      expect(saved['title'], 'Leg day');
      final exercises = saved['weeks'][0]['days'][0]['exercises'] as List;
      expect(exercises[1]['sets'][0]['weightKg'], 45.359);
      expect(exercises[2]['sets'][0]['weightKg'], 102.058);
      expect(find.text('Workout w-new'), findsOneWidget, reason: 'opens the new workout');
      expect(jobs.filesRemoved, ['u1/import-j1'], reason: 'the uploads are deleted once saved');
    });

    testWidgets('a file deletion that fails doesn\'t fail the save', (tester) async {
      await pump(tester, readyReview(programResult()));
      jobs.removeError = Exception('storage down');
      await tapKey(tester, 'ai_import_review_accept');
      expect(server.accepted, hasLength(1));
      expect(find.text('Program p-new'), findsOneWidget, reason: 'the daily cleanup deletes them instead');
    });

    testWidgets('a failed save keeps the review and can be retried', (tester) async {
      await pump(tester, readyReview(workoutResult()));
      await tester.tap(find.descendant(of: find.byKey(const Key('ai_import_review_unit')), matching: find.text('kg')));
      await tester.enterText(find.byKey(const Key('ai_import_review_title')), 'Kept title');
      await tester.pumpAndSettle();

      server.acceptError = Exception('offline');
      await tapKey(tester, 'ai_import_review_accept');

      expect(find.byKey(const Key('ai_import_review_error')), findsOneWidget);
      expect(find.text('Kept title'), findsOneWidget);
      expect(find.text('Front Squat'), findsOneWidget);
      expect(acceptButton(tester).onPressed, isNotNull);

      server.acceptError = null;
      await tapKey(tester, 'ai_import_review_accept');
      expect(server.accepted.single['title'], 'Kept title');
      expect(find.text('Workout w-new'), findsOneWidget);
    });

    testWidgets('a custom exercise fix applies to every occurrence', (tester) async {
      await pump(tester, readyReview(workoutResult()));
      expect(find.text('2 Hang Clean + 1 Jerk (2 times)'), findsOneWidget);

      await tapKey(tester, 'ai_import_review_fix_0');
      await tester.enterText(find.byKey(const Key('ai_import_fix_custom_name')), 'Clean complex');
      await tapKey(tester, 'ai_import_fix_custom');

      expect(find.text('Saved as a new custom exercise, "Clean complex"'), findsNWidgets(2));
      expect(find.textContaining('of Clean complex'), findsOneWidget);

      await tester.tap(find.descendant(of: find.byKey(const Key('ai_import_review_unit')), matching: find.text('kg')));
      await tester.pumpAndSettle();
      await tapKey(tester, 'ai_import_review_accept');

      final exercises = server.accepted.single['weeks'][0]['days'][0]['exercises'] as List;
      expect(exercises[3]['name'], 'Clean complex');
      expect(exercises[0]['sets'][0]['basisExercise']['name'], 'Clean complex');
    });

    testWidgets('a guess can be replaced with one of the user\'s exercises', (tester) async {
      await pump(tester, readyReview(workoutResult()));

      await tapKey(tester, 'ai_import_review_fix_1');
      await tester.enterText(find.byType(TextFormField), 'bench');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bench Press').last);
      await tester.pumpAndSettle();

      expect(find.text('Saved as Bench Press'), findsNWidgets(2));
      await tester.tap(find.descendant(of: find.byKey(const Key('ai_import_review_unit')), matching: find.text('kg')));
      await tester.pumpAndSettle();
      await tapKey(tester, 'ai_import_review_accept');
      final bench = (server.accepted.single['weeks'][0]['days'][0]['exercises'] as List)[2];
      expect(bench['match'], {'exerciseId': 'ex-bp', 'name': 'Bench Press', 'confidence': 'exact'});
    });
  });

  group('a program', () {
    testWidgets('previews weeks, days and rest days, and saves without a unit choice', (tester) async {
      await pump(tester, readyReview(programResult()));

      expect(find.text('Read as a program · 2 weeks · 2 training days · 2 rest days'), findsOneWidget);
      expect(find.text('Week 1'), findsOneWidget);
      expect(find.text('Week 2'), findsOneWidget);
      expect(find.text('MONDAY'), findsNWidgets(2));
      expect(find.text('TUESDAY'), findsNWidgets(2));
      expect(find.text('Rest day'), findsNWidgets(2));
      expect(find.byKey(const Key('ai_import_review_unit')), findsNothing);
      expect(find.byKey(const Key('ai_import_review_handwritten')), findsNothing);

      await tapKey(tester, 'ai_import_review_fix_0');
      await tester.enterText(find.byType(TextFormField), 'paused');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paused Back Squat'));
      await tester.pumpAndSettle();

      await tapKey(tester, 'ai_import_review_accept');
      final weeks = server.accepted.single['weeks'] as List;
      for (final week in weeks) {
        expect(week['days'][0]['exercises'][1]['match']['exerciseId'], 'ex-ps');
      }
      expect(find.text('Program p-new'), findsOneWidget, reason: 'opens the new program');
    });

    testWidgets('a long program can be scrolled to its last week', (tester) async {
      await pump(tester, readyReview(programResult(weeks: 16)), size: const Size(400, 800));
      expect(find.text('Week 16'), findsNothing, reason: 'built lazily');

      await tester.scrollUntilVisible(
        find.text('Week 16'),
        600,
        // The list's own Scrollable; the title field has one too.
        scrollable: find
            .descendant(of: find.byKey(const Key('ai_import_review_list')), matching: find.byType(Scrollable))
            .first,
      );
      expect(find.text('Week 16'), findsOneWidget);
      expect(find.byKey(const Key('ai_import_review_accept')), findsOneWidget, reason: 'Accept stays in reach');
    });
  });

  group('re-run and discard', () {
    testWidgets('re-runs as the other type after warning it uses an import', (tester) async {
      await pump(tester, readyReview(programResult()));

      await tapKey(tester, 'ai_import_review_rerun');
      expect(find.textContaining('uses one of your imports'), findsOneWidget);
      await tester.tap(find.text('Re-run'));
      await tester.pumpAndSettle();

      expect(server.reruns, [('import-j1', 'workout')]);
      expect(find.text('Home screen'), findsOneWidget);
    });

    testWidgets('a refused re-run explains why and stays on the review', (tester) async {
      await pump(tester, readyReview(programResult()));
      server.rerunError = const GenkitFlowException('RESOURCE_EXHAUSTED', 'daily_limit');

      await tapKey(tester, 'ai_import_review_rerun');
      await tester.tap(find.text('Re-run'));
      await tester.pumpAndSettle();

      expect(find.text("You've reached today's import limit."), findsOneWidget);
      expect(find.text('Week 1'), findsOneWidget);
    });

    testWidgets('cancelling the re-run does nothing', (tester) async {
      await pump(tester, readyReview(workoutResult()));
      await tapKey(tester, 'ai_import_review_rerun');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(server.reruns, isEmpty);
    });

    testWidgets('discards after confirming', (tester) async {
      await pump(tester, readyReview(workoutResult()));

      await tapKey(tester, 'ai_import_review_discard');
      await tester.tap(find.widgetWithText(FilledButton, 'Discard').last);
      await tester.pumpAndSettle();

      expect(jobs.discarded, ['j1']);
      expect(jobs.filesRemoved, ['u1/import-j1']);
      expect(server.accepted, isEmpty);
      expect(find.text('Home screen'), findsOneWidget);
    });
  });

  group('not reviewable', () {
    testWidgets('an accepted import links to what it became', (tester) async {
      await pump(tester, readyReview(workoutResult(), status: 'accepted'));
      expect(find.text('This import has already been saved.'), findsOneWidget);
      await tester.tap(find.text('Open workout'));
      await tester.pumpAndSettle();
      expect(find.text('Workout w-old'), findsOneWidget);
    });

    testWidgets('a missing import says so', (tester) async {
      await pump(tester, null);
      expect(find.text('This import is no longer available.'), findsOneWidget);
    });
  });
}
