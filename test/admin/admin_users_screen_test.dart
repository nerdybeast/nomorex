import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/admin/screens/admin_audit_log_screen.dart';
import 'package:nomorex/features/admin/screens/admin_users_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_users_fakes.dart';

void main() {
  late FakeAdminServer server;

  Future<void> pump(WidgetTester tester, Widget screen, {Size? size}) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(ProviderScope(
      overrides: adminUsersOverrides(server),
      child: MaterialApp(home: screen),
    ));
    await tester.pumpAndSettle();
  }

  String range(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('admin_page_range'))).data!;

  IconButton pageButton(WidgetTester tester, String key) => tester.widget<IconButton>(find.byKey(Key(key)));

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('admin_users_search')), text);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  Future<void> openUser(WidgetTester tester, String email) async {
    await search(tester, email);
    // Not the search box, which holds the same text.
    final results = find.byKey(const Key('admin_users_table')).evaluate().isEmpty
        ? find.byKey(const Key('admin_users_list'))
        : find.byKey(const Key('admin_users_table'));
    await tester.tap(find.descendant(of: results, matching: find.text(email)));
    await tester.pumpAndSettle();
  }

  // The controls sit under 25 rows, below the fold.
  Future<void> tapPage(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Switch adminSwitch(WidgetTester tester) => tester.widget<Switch>(find.byKey(const Key('admin_role_admin')));

  setUp(() => server = FakeAdminServer());

  group('users list', () {
    testWidgets('shows the first page as a table on a wide screen', (tester) async {
      await pump(tester, const AdminUsersScreen(), size: const Size(1200, 900));
      expect(find.byKey(const Key('admin_users_table')), findsOneWidget);
      expect(find.byKey(const Key('admin_users_list')), findsNothing);
      expect(find.text('user0@example.com'), findsOneWidget);
      expect(find.text('Lifter 0'), findsOneWidget);
      expect(find.text('Never'), findsOneWidget, reason: 'user1 has never signed in');
      expect(range(tester), '1–25 of 60');
      expect(pageButton(tester, 'admin_page_previous').onPressed, isNull);
    });

    testWidgets('shows a list on a phone', (tester) async {
      await pump(tester, const AdminUsersScreen(), size: const Size(400, 900));
      expect(find.byKey(const Key('admin_users_list')), findsOneWidget);
      expect(find.byKey(const Key('admin_users_table')), findsNothing);
    });

    testWidgets('pages forward and back', (tester) async {
      await pump(tester, const AdminUsersScreen(), size: const Size(1200, 900));
      await tapPage(tester, 'admin_page_next');
      expect(range(tester), '26–50 of 60');
      expect(find.text('user25@example.com'), findsOneWidget);

      await tapPage(tester, 'admin_page_next');
      expect(range(tester), '51–60 of 60');
      expect(pageButton(tester, 'admin_page_next').onPressed, isNull);

      await tapPage(tester, 'admin_page_previous');
      expect(range(tester), '26–50 of 60');
    });

    testWidgets('search narrows the list and goes back to the first page', (tester) async {
      await pump(tester, const AdminUsersScreen(), size: const Size(1200, 900));
      await tapPage(tester, 'admin_page_next');

      await search(tester, 'user5');
      expect(range(tester), '1–11 of 11', reason: 'user5 and user50–59');
      expect(pageButton(tester, 'admin_page_next').onPressed, isNull);
    });

    testWidgets('search also matches the display name', (tester) async {
      await pump(tester, const AdminUsersScreen(), size: const Size(1200, 900));
      await search(tester, 'lifter 4');
      expect(find.text('user4@example.com'), findsOneWidget);
      expect(find.text('user5@example.com'), findsNothing);
    });

    testWidgets('says when nothing matches', (tester) async {
      await pump(tester, const AdminUsersScreen(), size: const Size(1200, 900));
      await search(tester, 'nobody');
      expect(find.byKey(const Key('admin_users_empty')), findsOneWidget);
    });
  });

  group('roles', () {
    testWidgets("an admin can't remove their own admin role", (tester) async {
      await pump(tester, const AdminUsersScreen(), size: const Size(1200, 900));
      await openUser(tester, 'user0@example.com');
      expect(adminSwitch(tester).value, isTrue);
      expect(adminSwitch(tester).onChanged, isNull);
      expect(find.text("You can't remove your own admin role."), findsOneWidget);
    });

    testWidgets('making a user an admin asks first, then saves', (tester) async {
      await pump(tester, const AdminUsersScreen(), size: const Size(1200, 900));
      await openUser(tester, 'user1@example.com');
      expect(adminSwitch(tester).value, isFalse);

      await tester.tap(find.byKey(const Key('admin_role_admin')));
      await tester.pumpAndSettle();
      expect(find.text('Give user1@example.com the admin role?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Give role'));
      await tester.pumpAndSettle();

      final (function, params) = server.rpcCalls.single;
      expect(function, 'admin_grant_role');
      expect(params, {'p_user_id': 'u1', 'p_role': 'admin'});
      expect(adminSwitch(tester).value, isTrue);
    });

    testWidgets('cancelling changes nothing', (tester) async {
      await pump(tester, const AdminUsersScreen(), size: const Size(1200, 900));
      await openUser(tester, 'user3@example.com');
      await tester.tap(find.byKey(const Key('admin_role_admin')));
      await tester.pumpAndSettle();
      expect(find.text('Remove the admin role from user3@example.com?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(server.rpcCalls, isEmpty);
      expect(adminSwitch(tester).value, isTrue);
    });

    testWidgets('a refused change explains why and keeps the switch as it was', (tester) async {
      await pump(tester, const AdminUsersScreen(), size: const Size(400, 900));
      await openUser(tester, 'user3@example.com');
      server.error = const PostgrestException(message: 'forbidden: the admin role is required', code: 'P0001');

      await tester.tap(find.byKey(const Key('admin_role_admin')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove role'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('admin_user_error')), findsOneWidget);
      expect(find.textContaining("don't have permission"), findsOneWidget);
      expect(adminSwitch(tester).value, isTrue);
    });
  });

  group('audit log', () {
    testWidgets('shows each action as a sentence', (tester) async {
      server.audit.addAll([
        {
          'id': 'e2',
          'action': 'ai_imports_disabled',
          'actor_email': 'user0@example.com',
          'target_email': null,
          'details': <String, dynamic>{},
          'created_at': '2026-11-11T10:00:00Z',
        },
        {
          'id': 'e1',
          'action': 'role_granted',
          'actor_email': 'user0@example.com',
          'target_email': 'user1@example.com',
          'details': {'role': 'admin'},
          'created_at': '2026-11-10T10:00:00Z',
        },
      ]);
      await pump(tester, const AdminAuditLogScreen());
      expect(find.text('user0@example.com turned AI imports off'), findsOneWidget);
      expect(find.text('user0@example.com gave user1@example.com the admin role'), findsOneWidget);
      expect(range(tester), '1–2 of 2');
    });

    testWidgets('says when there is nothing yet', (tester) async {
      await pump(tester, const AdminAuditLogScreen());
      expect(find.text('No admin actions yet.'), findsOneWidget);
    });
  });
}
