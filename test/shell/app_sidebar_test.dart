import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nomorex/core/theme/app_theme.dart';
import 'package:nomorex/features/admin/providers/current_roles_provider.dart';
import 'package:nomorex/features/ai/models/ai_import_limits.dart';
import 'package:nomorex/features/ai/providers/ai_import_intake_provider.dart';
import 'package:nomorex/features/auth/providers/auth_provider.dart';
import 'package:nomorex/features/profile/providers/profile_provider.dart';
import 'package:nomorex/features/programs/models/program_instance.dart';
import 'package:nomorex/features/programs/providers/program_instances_list_provider.dart';
import 'package:nomorex/features/programs/utils/program_stats.dart';
import 'package:nomorex/features/shell/app_frame.dart';
import 'package:nomorex/features/shell/widgets/breadcrumb_title.dart';
import 'package:nomorex/features/workouts/models/workout.dart';
import 'package:nomorex/features/workouts/providers/in_progress_workouts_provider.dart';
import 'package:nomorex/shared/widgets/responsive_layout.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Workouts extends InProgressWorkoutsNotifier {
  _Workouts(this.items);
  final List<Workout> items;
  @override
  Future<List<Workout>> build() async => items;
}

class _Instances extends CurrentProgramInstancesNotifier {
  _Instances(this.items);
  final List<ProgramInstance> items;
  @override
  Future<List<ProgramInstance>> build() async => items;
}

Widget _page(String label, {Widget? title}) => Scaffold(
      appBar: AppBar(title: title ?? Text('$label bar')),
      body: Text('$label page'),
    );

Widget _app({
  String initial = '/shell/home',
  Set<String> roles = const {},
  bool importEnabled = true,
  List<Workout> workouts = const [],
  List<ProgramInstance> instances = const [],
}) {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppFrame(location: state.uri.path, child: child),
        routes: [
          for (final (path, label) in [
            ('/shell/home', 'Home'),
            ('/shell/programs', 'Programs'),
            ('/shell/workouts', 'Workouts'),
            ('/shell/prs', 'PRs'),
            ('/shell/community', 'Community'),
            ('/admin', 'Admin'),
            ('/prs/add', 'Add PR'),
            ('/workouts/new', 'New workout'),
            ('/programs/new', 'New program'),
            ('/ai-import', 'Import'),
          ])
            GoRoute(path: path, builder: (_, _) => _page(label)),
          GoRoute(
            path: '/programs/:id',
            builder: (_, _) => _page(
              'Program detail',
              title: const BreadcrumbTitle(title: 'Program', current: 'ZT 6 Week Program'),
            ),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, _) => Scaffold(
              appBar: AppBar(
                automaticallyImplyLeading: showsBackForSidebarDestination(context),
                title: const Text('Profile bar'),
              ),
              body: const Text('Profile page'),
            ),
          ),
          GoRoute(path: '/program-instances/:id', builder: (_, _) => _page('Run')),
          GoRoute(path: '/workouts/:id', builder: (_, _) => _page('Session')),
        ],
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      inProgressWorkoutsProvider.overrideWith(() => _Workouts(workouts)),
      currentProgramInstancesProvider.overrideWith(() => _Instances(instances)),
      currentUserRolesProvider.overrideWith((ref) async => roles),
      aiImportLimitsProvider.overrideWith(
        (ref) async => AiImportLimits(
          maxImages: 10,
          maxPdfPages: 10,
          maxImageBytes: 1,
          maxPdfBytes: 1,
          enabled: importEnabled,
        ),
      ),
      currentAuthUserProvider.overrideWithValue(null),
      displayNameProvider.overrideWithValue('Pat Lifter'),
    ],
    child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
  );
}

void _setWidth(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

final _sidebar = find.byKey(const Key('app_sidebar'));
Finder _inSidebar(String text) => find.descendant(of: _sidebar, matching: find.text(text));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a laptop window shows the expanded sidebar, and its sections navigate', (tester) async {
    _setWidth(tester, 1280);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(tester.getSize(_sidebar).width, 232);
    for (final label in ['Home', 'Programs', 'Workouts', 'My PRs', 'Community']) {
      expect(_inSidebar(label), findsOneWidget);
    }
    expect(find.byTooltip('Collapse sidebar'), findsOneWidget);

    await tester.tap(_inSidebar('Programs'));
    await tester.pumpAndSettle();
    expect(find.text('Programs page'), findsOneWidget);
  });

  testWidgets('screen readers can reach the sidebar beside a page', (tester) async {
    final semantics = tester.ensureSemantics();
    _setWidth(tester, 1280);
    await tester.pumpWidget(_app(initial: '/programs/p1'));
    await tester.pumpAndSettle();

    // Each page's route barrier would otherwise hide the sidebar, which is
    // painted before it.
    expect(find.bySemanticsLabel('Workouts'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Profile, Pat Lifter')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a tablet window opens collapsed, and the toggle expands and collapses it', (tester) async {
    _setWidth(tester, 800);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(tester.getSize(_sidebar).width, 76);
    await tester.tap(find.byTooltip('Expand sidebar'));
    await tester.pumpAndSettle();
    expect(tester.getSize(_sidebar).width, 232);

    await tester.tap(find.byTooltip('Collapse sidebar'));
    await tester.pumpAndSettle();
    expect(tester.getSize(_sidebar).width, 76);
  });

  testWidgets('a phone window has no sidebar', (tester) async {
    _setWidth(tester, 400);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(_sidebar, findsNothing);
    expect(find.text('Home page'), findsOneWidget);
  });

  testWidgets('[ toggles the sidebar', (tester) async {
    _setWidth(tester, 1280);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
    await tester.pumpAndSettle();
    expect(tester.getSize(_sidebar).width, 76);
  });

  testWidgets('New opens a menu of things to create, plus import while it is on', (tester) async {
    _setWidth(tester, 1280);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('shell_add_fab')));
    await tester.pumpAndSettle();
    for (final entry in ['New personal best', 'New workout', 'New program']) {
      expect(find.widgetWithText(MenuItemButton, entry), findsOneWidget);
    }
    expect(find.byKey(const Key('ai_import_entry')), findsOneWidget);

    await tester.tap(find.widgetWithText(MenuItemButton, 'New workout'));
    await tester.pumpAndSettle();
    expect(find.text('New workout page'), findsOneWidget);
  });

  testWidgets('New leaves out import while imports are switched off', (tester) async {
    _setWidth(tester, 1280);
    await tester.pumpWidget(_app(importEnabled: false));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('shell_add_fab')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(MenuItemButton, 'New program'), findsOneWidget);
    expect(find.byKey(const Key('ai_import_entry')), findsNothing);
  });

  testWidgets('the account card names the user and their plan, and opens Profile', (tester) async {
    _setWidth(tester, 1280);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(_inSidebar('Pat Lifter'), findsOneWidget);
    expect(_inSidebar('Free'), findsOneWidget);
    expect(_inSidebar('ADMIN'), findsNothing);
    expect(_inSidebar('Admin'), findsNothing);

    await tester.tap(find.byKey(const Key('sidebar_account')));
    await tester.pumpAndSettle();
    expect(find.text('Profile page'), findsOneWidget);
  });

  testWidgets('Profile opened from the sidebar keeps a way back after the window narrows', (tester) async {
    _setWidth(tester, 1280);
    await tester.pumpWidget(_app(initial: '/shell/programs'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sidebar_account')));
    await tester.pumpAndSettle();
    // A second click while it's showing doesn't stack another copy.
    await tester.tap(find.byKey(const Key('sidebar_account')));
    await tester.pumpAndSettle();
    expect(find.text('Profile page'), findsOneWidget);
    // Beside the sidebar there's no back arrow; the sidebar is the way back.
    expect(find.byTooltip('Back'), findsNothing);

    _setWidth(tester, 400);
    await tester.pumpAndSettle();
    expect(_sidebar, findsNothing);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Programs page'), findsOneWidget);
  });

  testWidgets('admins get the Admin row and the role pill', (tester) async {
    _setWidth(tester, 1280);
    await tester.pumpWidget(_app(roles: {'admin'}));
    await tester.pumpAndSettle();

    expect(_inSidebar('ADMIN'), findsOneWidget);
    await tester.tap(_inSidebar('Admin'));
    await tester.pumpAndSettle();
    expect(find.text('Admin page'), findsOneWidget);
  });

  testWidgets('Running says so when nothing is running', (tester) async {
    _setWidth(tester, 1280);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(_inSidebar('RUNNING'), findsOneWidget);
    expect(find.textContaining('Nothing running'), findsOneWidget);
  });

  testWidgets('Running shows a live session and today in a program run, and opens them', (tester) async {
    _setWidth(tester, 1280);
    final now = DateTime.now();
    await tester.pumpWidget(_app(
      workouts: [
        Workout(
          id: 'w1',
          userId: 'u',
          title: 'Push day',
          date: now,
          updatedAt: now,
          workoutGroupId: 'g1',
          status: 'in_progress',
          startedAt: now.subtract(const Duration(minutes: 5)),
        ),
      ],
      instances: [
        ProgramInstance(
          id: 'i1',
          programId: 'p1',
          userId: 'u',
          programName: 'ZT 6 Week Program',
          startedAt: DateTime(now.year, now.month, now.day),
          status: 'active',
          structure: const [
            StatsWeek([StatsDay(id: 'd1', position: 0, isRest: false)]),
          ],
        ),
      ],
    ));
    // The session clock ticks every second, so pump rather than settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(_inSidebar('Push day'), findsOneWidget);
    expect(_inSidebar('ZT 6 Week Program'), findsOneWidget);
    expect(find.textContaining('Week 1'), findsOneWidget);
    expect(find.textContaining('Nothing running'), findsNothing);

    await tester.tap(_inSidebar('ZT 6 Week Program'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Run page'), findsOneWidget);
  });

  testWidgets('a detail page keeps its section selected and leads its title with the section', (tester) async {
    _setWidth(tester, 1280);
    await tester.pumpWidget(_app(initial: '/programs/p1'));
    await tester.pumpAndSettle();

    expect(_sidebar, findsOneWidget);
    expect(find.byKey(const Key('breadcrumb_section')), findsOneWidget);
    expect(find.text('ZT 6 Week Program'), findsOneWidget);

    await tester.tap(find.byKey(const Key('breadcrumb_section')));
    await tester.pumpAndSettle();
    expect(find.text('Programs page'), findsOneWidget);
  });

  testWidgets('on a phone the detail title is the plain title', (tester) async {
    _setWidth(tester, 400);
    await tester.pumpWidget(_app(initial: '/programs/p1'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('breadcrumb_section')), findsNothing);
    expect(find.text('Program'), findsOneWidget);
  });
}
