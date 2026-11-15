import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nomorex/core/theme/app_theme.dart';
import 'package:nomorex/features/ai/models/ai_import_limits.dart';
import 'package:nomorex/features/ai/providers/ai_import_intake_provider.dart';
import 'package:nomorex/features/shell/app_shell.dart';

/// The phone shell's bottom bar and its New sheet. The sidebar's New menu is in
/// app_sidebar_test.
Widget _app({bool importEnabled = true}) {
  Widget page(String label) => Scaffold(body: Text('$label page'));
  final router = GoRouter(
    initialLocation: '/shell/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          for (final (path, label) in [
            ('/shell/home', 'Home'),
            ('/shell/training', 'Training'),
            ('/shell/community', 'Community'),
          ])
            StatefulShellBranch(routes: [GoRoute(path: path, builder: (_, _) => page(label))]),
        ],
      ),
      for (final (path, label) in [
        ('/prs/add', 'Add PR'),
        ('/workouts/new', 'New workout'),
        ('/programs/new', 'New program'),
        ('/ai-import', 'Import'),
      ])
        GoRoute(path: path, builder: (_, _) => page(label)),
    ],
  );
  return ProviderScope(
    overrides: [
      aiImportLimitsProvider.overrideWith(
        (ref) async => AiImportLimits(
          maxImages: 10,
          maxPdfPages: 10,
          maxImageBytes: 1,
          maxPdfBytes: 1,
          enabled: importEnabled,
        ),
      ),
    ],
    child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
}

void main() {
  Future<void> openSheet(WidgetTester tester, {bool importEnabled = true}) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(importEnabled: importEnabled));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shell_new')));
    await tester.pumpAndSettle();
  }

  testWidgets('the New sheet offers import while it is on, and opens it', (tester) async {
    await openSheet(tester);
    for (final entry in ['New personal best', 'New workout', 'New program']) {
      expect(find.widgetWithText(ListTile, entry), findsOneWidget);
    }
    expect(find.widgetWithText(ListTile, 'Import from photos or PDFs'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ai_import_entry')));
    await tester.pumpAndSettle();
    expect(find.text('Import page'), findsOneWidget);
  });

  testWidgets('the New sheet leaves out import while imports are switched off', (tester) async {
    await openSheet(tester, importEnabled: false);
    expect(find.widgetWithText(ListTile, 'New program'), findsOneWidget);
    expect(find.byKey(const Key('ai_import_entry')), findsNothing);
  });

  testWidgets('the bottom bar is Home, Training, Community and New, with no FAB over the page', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);
    for (final label in ['Home', 'Training', 'Community', 'New']) {
      expect(find.bySemanticsLabel(label), findsOneWidget, reason: '$label in the bar');
    }
    // Same row as the tabs.
    expect(
      tester.getCenter(find.byKey(const Key('shell_new'))).dy,
      tester.getCenter(find.bySemanticsLabel('Home')).dy,
    );
  });

  testWidgets('the bar fits a narrow phone without overflowing', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('Community'), findsOneWidget);
  });
}
