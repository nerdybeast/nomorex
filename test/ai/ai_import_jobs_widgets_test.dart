import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/ai/providers/ai_import_jobs_provider.dart';
import 'package:nomorex/features/ai/widgets/ai_import_job_alerts.dart';
import 'package:nomorex/features/ai/widgets/ai_import_jobs_section.dart';

import 'ai_import_job_fakes.dart';

void main() {
  late FakeJobServer server;
  late FakeSubscriber subscriber;
  late List<String> navigatedTo;

  setUp(() {
    server = FakeJobServer();
    subscriber = FakeSubscriber();
    navigatedTo = [];
  });

  /// The app shape: alerts wrapping everything, Home's card on a Scaffold.
  Future<ProviderContainer> pump(WidgetTester tester, List<dynamic> jobs) async {
    server.jobs['u1'] = [...jobs.cast()];
    await tester.pumpWidget(
      ProviderScope(
        overrides: jobOverrides(server, subscriber),
        child: MaterialApp(
          builder: (context, child) => AiImportJobAlerts(navigate: navigatedTo.add, child: child!),
          home: const Scaffold(body: SingleChildScrollView(child: AiImportJobsSection())),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return ProviderScope.containerOf(tester.element(find.byType(AiImportJobsSection)));
  }

  /// Simulates the job changing on the server and a Realtime event arriving.
  Future<void> serverChanges(WidgetTester tester, List<dynamic> jobs) async {
    server.jobs['u1'] = [...jobs.cast()];
    subscriber.onChange!();
    await tester.pump();
    await tester.pump();
  }

  group('Home card', () {
    testWidgets('shows nothing without imports', (tester) async {
      await pump(tester, const []);
      expect(find.byKey(const Key('ai_import_jobs_section')), findsNothing);
    });

    testWidgets('shows a processing import', (tester) async {
      await pump(tester, [testJob('a', 'processing')]);
      expect(find.text('Reading your import…'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('a ready import links to its review', (tester) async {
      await pump(tester, [testJob('a', 'ready', type: 'program')]);
      expect(find.text('Program ready to review'), findsOneWidget);
      expect(find.byKey(const Key('ai_import_job_review_a')), findsOneWidget);
    });

    testWidgets('a failed import explains why and can be dismissed', (tester) async {
      await pump(tester, [testJob('a', 'failed', failureCode: 'no_workout_found'), testJob('b', 'ready')]);
      expect(find.text('Import failed'), findsOneWidget);
      expect(find.text("We couldn't find a workout or program in those files."), findsOneWidget);

      await tester.tap(find.byKey(const Key('ai_import_job_dismiss_a')));
      await tester.pump();
      await tester.pump();

      expect(server.discarded, ['a']);
      expect(find.text('Import failed'), findsNothing);
      expect(find.text('Workout ready to review'), findsOneWidget);
    });

    testWidgets('a processing import past its time limit shows as failed', (tester) async {
      await pump(tester, [testJob('a', 'processing', age: const Duration(minutes: 4))]);
      expect(find.text('Import failed'), findsOneWidget);
      expect(find.textContaining('stopped before it finished'), findsOneWidget);
      expect(
        find.byKey(const Key('ai_import_job_dismiss_a')),
        findsNothing,
        reason: 'the server still has it processing, so it can\'t be discarded yet',
      );
    });
  });

  group('alerts', () {
    testWidgets('imports already finished at launch don\'t alert', (tester) async {
      await pump(tester, [testJob('a', 'ready'), testJob('b', 'failed')]);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('alert once when an import becomes ready, with a link to review', (tester) async {
      await pump(tester, [testJob('a', 'processing')]);
      expect(subscriber.subscribed, isTrue);

      await serverChanges(tester, [testJob('a', 'ready')]);
      await tester.pumpAndSettle();
      expect(find.text('Your imported workout is ready to review.'), findsOneWidget);

      await tester.tap(find.descendant(of: find.byType(SnackBar), matching: find.text('Review')));
      expect(navigatedTo, ['/ai-import/review/a']);

      // Another re-read of the same job: no second alert.
      await tester.pumpAndSettle(const Duration(seconds: 10));
      server.jobs['u1'] = [testJob('a', 'ready')];
      final container = ProviderScope.containerOf(tester.element(find.byType(AiImportJobsSection)));
      container.invalidate(aiImportJobsProvider);
      await tester.pump();
      await tester.pump();
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('alerts when an import fails, linking to Home', (tester) async {
      await pump(tester, [testJob('a', 'processing')]);
      await serverChanges(tester, [testJob('a', 'failed', failureCode: 'timeout')]);
      await tester.pumpAndSettle();

      expect(find.textContaining('An import failed. Reading the files took too long.'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(SnackBar), matching: find.text('View')));
      expect(navigatedTo, ['/shell/home']);
    });

    testWidgets('re-reads the imports when the app resumes', (tester) async {
      await pump(tester, [testJob('a', 'ready')]);
      final before = server.fetches;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      server.jobs['u1'] = [testJob('a', 'ready'), testJob('b', 'ready')];
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(server.fetches, before + 1);
      expect(find.text('Workout ready to review'), findsNWidgets(2));
    });

    testWidgets('signing out clears the card and the subscription', (tester) async {
      final container = await pump(tester, [testJob('a', 'processing')]);
      expect(find.text('Reading your import…'), findsOneWidget);
      expect(subscriber.subscribed, isTrue);

      container.read(testUserProvider.notifier).set(null);
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('ai_import_jobs_section')), findsNothing);
      expect(subscriber.subscribed, isFalse);
    });

    testWidgets('another user\'s finished import never alerts after a switch', (tester) async {
      final container = await pump(tester, [testJob('a', 'processing')]);
      server.jobs['u2'] = [testJob('z', 'ready')];

      container.read(testUserProvider.notifier).set(testUser('u2'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Workout ready to review'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing, reason: 'the new user\'s first read is their baseline');
    });
  });
}
