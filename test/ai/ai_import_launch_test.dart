import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nomorex/features/ai/models/ai_import_limits.dart';
import 'package:nomorex/features/ai/providers/ai_import_gate_provider.dart';
import 'package:nomorex/features/ai/screens/ai_import_screen.dart';
import 'package:nomorex/features/ai/widgets/ai_import_button.dart';
import 'package:nomorex/features/ai/widgets/ai_import_jobs_section.dart';

import 'ai_import_job_fakes.dart';

/// The launch surface (#88): the entry point, the one-time notice and every
/// message a user can meet when they can't import or an import fails.
void main() {
  late FakeGate gate;

  /// Home (with the entry point) and the import screen, as in the app.
  Future<GoRouter> pump(WidgetTester tester, AiImportCheck check, {bool enabled = true, Object? consentError}) async {
    gate = FakeGate(check, consentError: consentError);
    final router = GoRouter(
      initialLocation: '/shell/home',
      routes: [
        GoRoute(
          path: '/shell/home',
          builder: (_, _) => Scaffold(
            appBar: AppBar(title: const Text('Workouts'), actions: const [AiImportButton()]),
            body: const Text('Workouts screen'),
          ),
        ),
        GoRoute(path: '/ai-import', builder: (_, _) => const AiImportScreen()),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...jobOverrides(
            FakeJobServer(),
            FakeSubscriber(),
            limits: AiImportLimits(
              maxImages: 8,
              maxPdfPages: 10,
              maxImageBytes: 7000000,
              maxPdfBytes: 20000000,
              enabled: enabled,
            ),
          ),
          aiImportGateProvider.overrideWith(() => gate),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> openImport(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('ai_import_entry')));
    await tester.pumpAndSettle();
  }

  group('entry point', () {
    testWidgets('opens the import flow, with a label for screen readers', (tester) async {
      await pump(tester, const AiImportCheck(allowed: true));
      expect(find.byTooltip('Import from photos or PDFs'), findsOneWidget);
      await openImport(tester);
      expect(find.byKey(const Key('ai_import_choose_images')), findsOneWidget);
    });

    testWidgets('is hidden while imports are switched off', (tester) async {
      await pump(tester, const AiImportCheck(allowed: true), enabled: false);
      expect(find.byKey(const Key('ai_import_entry')), findsNothing);
    });
  });

  group('one-time notice', () {
    const firstTime = AiImportCheck(allowed: false, reason: 'consent_required');

    testWidgets('comes before any file can be chosen, and names Anthropic', (tester) async {
      await pump(tester, firstTime);
      await openImport(tester);

      expect(find.byKey(const Key('ai_import_notice')), findsOneWidget);
      expect(find.textContaining('Anthropic'), findsWidgets);
      expect(find.textContaining('deleted from NoMoreX'), findsOneWidget);
      expect(find.byKey(const Key('ai_import_choose_images')), findsNothing);
      expect(find.byKey(const Key('ai_import_choose_pdf')), findsNothing);
    });

    testWidgets('declining leaves without recording or uploading anything', (tester) async {
      await pump(tester, firstTime);
      await openImport(tester);

      await tester.tap(find.byKey(const Key('ai_import_notice_decline')));
      await tester.pumpAndSettle();

      expect(find.text('Workouts screen'), findsOneWidget);
      expect(gate.consents, 0);
    });

    testWidgets('accepting records it and goes on to choosing files', (tester) async {
      await pump(tester, firstTime);
      await openImport(tester);

      await tester.tap(find.byKey(const Key('ai_import_notice_accept')));
      await tester.pumpAndSettle();

      expect(gate.consents, 1);
      expect(find.byKey(const Key('ai_import_notice')), findsNothing);
      expect(find.byKey(const Key('ai_import_choose_images')), findsOneWidget);
    });

    testWidgets('a failed save keeps the notice up to try again', (tester) async {
      await pump(tester, firstTime, consentError: Exception('offline'));
      await openImport(tester);

      await tester.tap(find.byKey(const Key('ai_import_notice_accept')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ai_import_notice_error')), findsOneWidget);
      expect(find.byKey(const Key('ai_import_choose_images')), findsNothing);
    });
  });

  group('when an import can\'t start', () {
    Future<String> refusal(WidgetTester tester, AiImportCheck check) async {
      await pump(tester, check);
      await openImport(tester);
      expect(find.byKey(const Key('ai_import_choose_images')), findsNothing, reason: 'no files offered');
      return tester.widget<Text>(find.byKey(const Key('ai_import_refused'))).data!;
    }

    testWidgets('imports switched off', (tester) async {
      expect(
        await refusal(tester, const AiImportCheck(allowed: false, reason: 'imports_disabled')),
        'Imports are switched off right now. Try again later.',
      );
    });

    testWidgets('an import already running, with a way to see it', (tester) async {
      expect(
        await refusal(tester, const AiImportCheck(allowed: false, reason: 'active_import')),
        'An import is already running. Wait for it to finish, then try again.',
      );
      expect(find.byKey(const Key('ai_import_refused_home')), findsOneWidget);
    });

    testWidgets('the daily cap, and when it resets', (tester) async {
      final message = await refusal(
        tester,
        AiImportCheck(
          allowed: false,
          reason: 'daily_limit',
          dailyLimit: 5,
          resetsAt: DateTime(2026, 11, 11, 7, 30).toUtc(),
        ),
      );
      // intl separates "AM" with a narrow no-break space, so format it the same way.
      final time = DateFormat.jm().format(DateTime(2026, 11, 11, 7, 30));
      expect(message, "You've used all 5 of today's imports. You can import again at $time.");
    });

    testWidgets('the monthly cap, and when it resets', (tester) async {
      final message = await refusal(
        tester,
        AiImportCheck(
          allowed: false,
          reason: 'monthly_limit',
          monthlyLimit: 30,
          resetsAt: DateTime(2026, 12, 1).toUtc(),
        ),
      );
      expect(message, "You've used all 30 of this month's imports. You can import again on Dec 1.");
    });
  });

  group('when an import fails', () {
    Future<void> failed(WidgetTester tester, String code) async {
      final server = FakeJobServer()..jobs['u1'] = [testJob('a', 'failed', failureCode: code)];
      await tester.pumpWidget(
        ProviderScope(
          overrides: jobOverrides(server, FakeSubscriber()),
          child: const MaterialApp(home: Scaffold(body: AiImportJobsSection())),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('no workout found', (tester) async {
      await failed(tester, 'no_workout_found');
      expect(find.text("We couldn't find a workout or program in those files."), findsOneWidget);
    });

    testWidgets('processing ran out of time', (tester) async {
      await failed(tester, 'timeout');
      expect(find.text('Reading the files took too long. Try fewer pages.'), findsOneWidget);
    });
  });
}
