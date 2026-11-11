import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nomorex/core/constants/app_constants.dart';
import 'package:nomorex/features/admin/screens/admin_ai_imports_screen.dart';
import 'package:nomorex/features/admin/screens/admin_screen.dart';
import 'package:nomorex/features/admin/utils/admin_route_guard.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_test_support.dart';

/// The admin hub and the AI import switch, behind the same route guard the
/// app uses.
void main() {
  late FakeAiImportsServer server;

  Future<GoRouter> pump(
    WidgetTester tester, {
    Set<String> roles = adminRoles,
    Future<Set<String>> Function()? readRoles,
    String initialLocation = AppConstants.routeAdmin,
    bool enabled = true,
  }) async {
    server = FakeAiImportsServer(enabled: enabled);
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(path: AppConstants.routeProfile, builder: (_, _) => const Scaffold(body: Text('Profile screen'))),
        GoRoute(
          path: AppConstants.routeAdmin,
          redirect: (_, _) => adminRouteRedirect(readRoles ?? () async => roles),
          builder: (_, _) => const AdminScreen(),
          routes: [GoRoute(path: 'ai-imports', builder: (_, _) => const AdminAiImportsScreen())],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [rolesOverride(roles), ...aiImportsOverrides(server)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Switch aiSwitch(WidgetTester tester) => tester.widget<Switch>(
        find.descendant(of: find.byKey(const Key('admin_ai_imports_switch')), matching: find.byType(Switch)),
      );

  Future<void> tapSwitch(WidgetTester tester) async {
    await tester.tap(find.descendant(
      of: find.byKey(const Key('admin_ai_imports_switch')),
      matching: find.byType(Switch),
    ));
    await tester.pumpAndSettle();
  }

  group('route guard', () {
    testWidgets('a non-admin sent to /admin lands on Profile', (tester) async {
      await pump(tester, roles: const {});
      expect(find.text('Profile screen'), findsOneWidget);
      expect(find.text('Admin'), findsNothing);
    });

    testWidgets('a non-admin deep-linking to a section lands on Profile', (tester) async {
      await pump(tester, roles: const {}, initialLocation: AppConstants.routeAdminAiImports);
      expect(find.text('Profile screen'), findsOneWidget);
    });

    testWidgets('roles that fail to load land on Profile', (tester) async {
      await pump(tester, readRoles: () async => throw Exception('offline'));
      expect(find.text('Profile screen'), findsOneWidget);
    });

    testWidgets('an admin reaches the hub', (tester) async {
      await pump(tester);
      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('Profile screen'), findsNothing);
    });
  });

  group('hub', () {
    testWidgets('lists the AI imports section and opens it', (tester) async {
      await pump(tester);
      expect(find.text('AI imports'), findsOneWidget);

      await tester.tap(find.byKey(const Key('admin_section_${AppConstants.routeAdminAiImports}')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('admin_ai_imports_switch')), findsOneWidget);
    });

    testWidgets('a section needing a role the user lacks is hidden', (tester) async {
      // The guard is bypassed here so the hub itself has to filter: a user with
      // only some other role sees no admin sections, and the gate says so.
      await pump(tester, roles: const {'moderator'}, readRoles: () async => {'admin'});
      expect(find.text('AI imports'), findsNothing);
      expect(find.byKey(const Key('admin_no_access')), findsOneWidget);
    });
  });

  group('AI import switch', () {
    testWidgets('shows the current value', (tester) async {
      await pump(tester, initialLocation: AppConstants.routeAdminAiImports, enabled: false);
      expect(aiSwitch(tester).value, isFalse);
      expect(find.textContaining('Nobody can start an import'), findsOneWidget);
    });

    testWidgets('turning off asks first, then saves', (tester) async {
      await pump(tester, initialLocation: AppConstants.routeAdminAiImports);
      await tapSwitch(tester);
      expect(find.text('Turn off AI imports?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Turn off'));
      await tester.pumpAndSettle();
      expect(server.calls, [false]);
      expect(aiSwitch(tester).value, isFalse);
    });

    testWidgets('cancelling leaves imports on', (tester) async {
      await pump(tester, initialLocation: AppConstants.routeAdminAiImports);
      await tapSwitch(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(server.calls, isEmpty);
      expect(aiSwitch(tester).value, isTrue);
    });

    testWidgets('turning on saves without asking', (tester) async {
      await pump(tester, initialLocation: AppConstants.routeAdminAiImports, enabled: false);
      await tapSwitch(tester);
      expect(find.text('Turn off AI imports?'), findsNothing);
      expect(server.calls, [true]);
      expect(aiSwitch(tester).value, isTrue);
    });

    testWidgets('a refused change shows a plain message and keeps the old value', (tester) async {
      await pump(tester, initialLocation: AppConstants.routeAdminAiImports, enabled: false);
      server.error = const PostgrestException(message: 'forbidden: the admin role is required', code: 'P0001');
      await tapSwitch(tester);
      expect(find.textContaining("You don't have permission"), findsOneWidget);
      expect(aiSwitch(tester).value, isFalse);
    });
  });
}
