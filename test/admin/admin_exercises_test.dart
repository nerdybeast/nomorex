import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/core/theme/app_theme.dart';
import 'package:nomorex/features/admin/models/admin_audit_entry.dart';
import 'package:nomorex/features/admin/models/admin_exercise.dart';
import 'package:nomorex/features/admin/models/app_roles.dart';
import 'package:nomorex/features/admin/providers/admin_exercises_provider.dart';
import 'package:nomorex/features/admin/providers/current_roles_provider.dart';
import 'package:nomorex/features/admin/screens/admin_exercises_screen.dart';
import 'package:nomorex/features/admin/utils/admin_error.dart';
import 'package:nomorex/features/admin/utils/audit_entry_text.dart';
import 'package:nomorex/features/auth/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_users_fakes.dart' show kSignedInAdmin;

/// Stands in for the admin exercise functions.
class _FakeExerciseServer {
  final rows = <Map<String, dynamic>>[
    _row('back_squat', 'Back Squat', aliases: ['Squat'], usage: 3),
    _row('clean_and_jerk', 'Clean & Jerk', aliases: ['C&J'], usage: 1),
    _row('box_squat', 'Box Squat'),
    _row('old_lift', 'Old Lift', retired: true),
  ];
  final calls = <(String, Map<String, dynamic>)>[];

  /// Returned by admin_create_exercise as custom_name_count.
  int customNameCount = 0;

  /// Thrown by the next change instead of saving, when set.
  Object? error;

  static Map<String, dynamic> _row(String slug, String name,
          {List<String> aliases = const [], int usage = 0, bool retired = false}) =>
      {
        'id': 'id_$slug',
        'slug': slug,
        'name': name,
        'aliases': aliases,
        'usage_count': usage,
        'retired_at': retired ? '2026-11-01T00:00:00Z' : null,
      };
}

class _FakeList extends AdminExercisesNotifier {
  _FakeList(this.server);
  final _FakeExerciseServer server;

  @override
  Future<List<Map<String, dynamic>>> fetchRows(String search, bool retired, int limit, int offset) async {
    final q = search.toLowerCase();
    final matches = [
      for (final r in server.rows)
        if ((r['retired_at'] != null) == retired &&
            (q.isEmpty ||
                (r['name'] as String).toLowerCase().contains(q) ||
                (r['slug'] as String).contains(q) ||
                (r['aliases'] as List).any((a) => (a as String).toLowerCase().contains(q))))
          r,
    ];
    return [for (final r in matches.skip(offset).take(limit)) {...r, 'total_count': matches.length}];
  }
}

class _FakeActions extends AdminExerciseActionsNotifier {
  _FakeActions(this.server);
  final _FakeExerciseServer server;

  @override
  Future<dynamic> callRpc(String fn, Map<String, dynamic> params) async {
    server.calls.add((fn, params));
    // Answer later, like the network: an instant reply hid an auto-dispose bug.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (fn == 'admin_export_exercises') return '-- The official exercise catalog\ninsert into ...';
    final error = server.error;
    if (error != null) {
      server.error = null;
      throw error;
    }
    Map<String, dynamic> row() => server.rows.firstWhere((r) => r['id'] == params['p_exercise_id']);
    switch (fn) {
      case 'admin_create_exercise':
        server.rows.add(_FakeExerciseServer._row(params['p_slug'] as String, params['p_name'] as String,
            aliases: params['p_aliases'] as List<String>));
        return [
          {'id': 'id_${params['p_slug']}', 'custom_name_count': server.customNameCount},
        ];
      case 'admin_update_exercise':
        row()
          ..['name'] = params['p_name']
          ..['aliases'] = params['p_aliases'];
      case 'admin_set_exercise_retired':
        row()['retired_at'] = params['p_retired'] == true ? '2026-11-14T00:00:00Z' : null;
      case 'admin_delete_exercise':
        server.rows.remove(row());
    }
    return null;
  }
}

PostgrestException _serverError(String message) => PostgrestException(message: message, code: 'P0001');

void main() {
  late _FakeExerciseServer server;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentAuthUserProvider.overrideWithValue(kSignedInAdmin),
        currentUserRolesProvider.overrideWith((ref) async => {AppRoles.admin}),
        adminExercisesProvider.overrideWith2((_) => _FakeList(server)),
        adminExerciseActionsProvider.overrideWith(() => _FakeActions(server)),
      ],
      // The app theme, not a bare MaterialApp: its full-width buttons once crashed this screen.
      child: MaterialApp(theme: AppTheme.light(), home: const AdminExercisesScreen()),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester, String slug) async {
    await tester.tap(find.byKey(ValueKey('admin_exercise_menu_$slug')));
    await tester.pumpAndSettle();
  }

  Future<void> openAdd(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('admin_exercises_add')));
    await tester.pumpAndSettle();
  }

  setUp(() => server = _FakeExerciseServer());

  group('list', () {
    testWidgets('shows active exercises with slug, other names and usage', (tester) async {
      await pump(tester);
      expect(find.text('Back Squat'), findsOneWidget);
      expect(find.text('back_squat'), findsOneWidget);
      expect(find.text('Also: Squat'), findsOneWidget);
      expect(find.text('Used by 3 lifters'), findsOneWidget);
      expect(find.text('Used by 1 lifter'), findsOneWidget);
      expect(find.text('Not used yet'), findsOneWidget);
      expect(find.text('Old Lift'), findsNothing);
    });

    testWidgets('the Retired filter shows retired exercises', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Retired'));
      await tester.pumpAndSettle();
      expect(find.text('Old Lift'), findsOneWidget);
      expect(find.text('Back Squat'), findsNothing);
    });

    testWidgets('search matches other names', (tester) async {
      await pump(tester);
      await tester.enterText(find.byKey(const Key('admin_exercises_search')), 'c&j');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Clean & Jerk'), findsOneWidget);
      expect(find.text('Back Squat'), findsNothing);
    });
  });

  group('add', () {
    testWidgets('suggests a slug from the name and saves', (tester) async {
      await pump(tester);
      await openAdd(tester);
      await tester.enterText(find.byKey(const Key('admin_exercise_name')), 'Push  Press');
      await tester.enterText(find.byKey(const Key('admin_exercise_aliases')), 'PP, , Push-Press');
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byKey(const Key('admin_exercise_slug'))).controller!.text, 'push_press');

      await tester.tap(find.byKey(const Key('admin_exercise_save')));
      await tester.pumpAndSettle();

      expect(server.calls.single.$1, 'admin_create_exercise');
      expect(server.calls.single.$2, {
        'p_slug': 'push_press',
        'p_name': 'Push Press',
        'p_aliases': ['PP', 'Push-Press'],
      });
      expect(find.text('Added Push Press.'), findsOneWidget);
      expect(find.text('Push Press'), findsOneWidget, reason: 'the list re-reads');
    });

    testWidgets('warns when lifters already have a custom exercise by that name', (tester) async {
      server.customNameCount = 4;
      await pump(tester);
      await openAdd(tester);
      await tester.enterText(find.byKey(const Key('admin_exercise_name')), 'Zercher Squat');
      await tester.tap(find.byKey(const Key('admin_exercise_save')));
      await tester.pumpAndSettle();
      expect(find.textContaining('4 lifters already have their own "Zercher Squat"'), findsOneWidget);
    });

    testWidgets('checks the name and slug before saving', (tester) async {
      await pump(tester);
      await openAdd(tester);
      await tester.tap(find.byKey(const Key('admin_exercise_save')));
      await tester.pumpAndSettle();
      expect(find.text('Enter a name'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('admin_exercise_name')), 'Zercher Squat');
      await tester.enterText(find.byKey(const Key('admin_exercise_slug')), 'Zercher-Squat');
      await tester.tap(find.byKey(const Key('admin_exercise_save')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Lowercase letters and numbers'), findsOneWidget);
      expect(server.calls, isEmpty);
    });

    testWidgets('a refused save stays open and says why', (tester) async {
      server.error = _serverError('duplicate: "Clean & Jerk" already uses one of these names or aliases');
      await pump(tester);
      await openAdd(tester);
      await tester.enterText(find.byKey(const Key('admin_exercise_name')), 'C&J');
      await tester.tap(find.byKey(const Key('admin_exercise_save')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('admin_exercise_error'))).data,
        '"Clean & Jerk" already uses one of these names or aliases.',
      );
      expect(find.byKey(const Key('admin_exercise_save')), findsOneWidget);
    });
  });

  group('edit', () {
    testWidgets('renaming keeps the old name as another name, visibly', (tester) async {
      await pump(tester);
      await openMenu(tester, 'back_squat');
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      final aliases = find.byKey(const Key('admin_exercise_aliases'));
      String aliasText() => tester.widget<TextField>(aliases).controller!.text;
      expect(aliasText(), 'Squat');

      await tester.enterText(find.byKey(const Key('admin_exercise_name')), 'High Bar Back Squat');
      await tester.pumpAndSettle();
      expect(aliasText(), 'Squat, Back Squat');
      expect(find.textContaining('The old name is kept'), findsOneWidget);

      // Renaming back takes it out again.
      await tester.enterText(find.byKey(const Key('admin_exercise_name')), 'Back Squat');
      await tester.pumpAndSettle();
      expect(aliasText(), 'Squat');

      await tester.enterText(find.byKey(const Key('admin_exercise_name')), 'High Bar Back Squat');
      await tester.tap(find.byKey(const Key('admin_exercise_save')));
      await tester.pumpAndSettle();
      expect(server.calls.single.$1, 'admin_update_exercise');
      expect(server.calls.single.$2, {
        'p_exercise_id': 'id_back_squat',
        'p_name': 'High Bar Back Squat',
        'p_aliases': ['Squat', 'Back Squat'],
      });
      expect(find.text('High Bar Back Squat'), findsOneWidget);
    });
  });

  group('retire, restore, delete', () {
    testWidgets('retiring asks first, then moves it to Retired', (tester) async {
      await pump(tester);
      await openMenu(tester, 'box_squat');
      await tester.tap(find.text('Retire'));
      await tester.pumpAndSettle();
      expect(find.text('Retire Box Squat?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Retire'));
      await tester.pumpAndSettle();

      expect(server.calls.single.$1, 'admin_set_exercise_retired');
      expect(find.text('Box Squat'), findsNothing);

      await tester.tap(find.text('Retired'));
      await tester.pumpAndSettle();
      await openMenu(tester, 'box_squat');
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      expect(server.calls.last.$2, {'p_exercise_id': 'id_box_squat', 'p_retired': false});
    });

    testWidgets('delete is offered only for an exercise nobody uses', (tester) async {
      await pump(tester);
      await openMenu(tester, 'back_squat');
      final inUse = tester.widget(find.ancestor(
        of: find.text('Delete (in use, retire instead)'),
        matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
      )) as PopupMenuItem;
      expect(inUse.enabled, isFalse);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      await openMenu(tester, 'box_squat');
      await tester.tap(find.text('Delete permanently'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete permanently'));
      await tester.pumpAndSettle();
      expect(server.calls.single.$1, 'admin_delete_exercise');
      expect(server.calls.single.$2, {'p_exercise_id': 'id_box_squat'});
      expect(find.text('Box Squat'), findsNothing);
    });
  });

  testWidgets('export shows the catalog file and copies it', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await pump(tester);
    await tester.tap(find.byTooltip('Export catalog'));
    await tester.pumpAndSettle();
    expect(find.textContaining('-- The official exercise catalog'), findsOneWidget);

    await tester.tap(find.byKey(const Key('admin_exercises_copy')));
    await tester.pumpAndSettle();
    expect(copied, startsWith('-- The official exercise catalog'));
  });

  group('helpers', () {
    test('suggestExerciseSlug follows the catalog rule', () {
      expect(suggestExerciseSlug('Clean & Jerk'), 'clean_and_jerk');
      expect(suggestExerciseSlug('  Power Clean + Push Press '), 'power_clean_push_press');
      expect(suggestExerciseSlug('Pull-Up'), 'pull_up');
      expect(kExerciseSlugPattern.hasMatch(suggestExerciseSlug('GHD Sit-Up')), isTrue);
    });

    test('parseAliases trims and drops blanks', () {
      expect(parseAliases(' C&J, ,Clean and Jerk ,'), ['C&J', 'Clean and Jerk']);
      expect(parseAliases(''), isEmpty);
    });

    test('AdminExercise reads a row from admin_list_exercises', () {
      final e = AdminExercise.fromJson({
        'id': 'x',
        'slug': 'old_lift',
        'name': 'Old Lift',
        'aliases': ['OL'],
        'usage_count': 2,
        'retired_at': '2026-11-01T00:00:00Z',
        'created_at': '2026-01-01T00:00:00Z',
        'total_count': 9,
      });
      expect(e.isRetired, isTrue);
      expect(e.canDelete, isFalse);
      expect(e.aliases, ['OL']);
    });

    test('catalog changes read as sentences in the audit log', () {
      AdminAuditEntry entry(String action, Map<String, dynamic> details) => AdminAuditEntry(
            id: '1',
            action: action,
            details: details,
            createdAt: DateTime(2026),
            actorEmail: 'a@a.com',
          );
      expect(describeAuditEntry(entry('exercise_created', {'name': 'Push Press'})),
          'a@a.com added the exercise Push Press');
      expect(describeAuditEntry(entry('exercise_updated', {'old_name': 'Clean', 'name': 'Squat Clean'})),
          'a@a.com renamed the exercise Clean to Squat Clean');
      expect(describeAuditEntry(entry('exercise_updated', {'old_name': 'Clean', 'name': 'Clean'})),
          "a@a.com changed Clean's other names");
      expect(describeAuditEntry(entry('exercise_retired', {'name': 'Old Lift'})),
          'a@a.com retired the exercise Old Lift');
      expect(describeAuditEntry(entry('exercise_restored', {'name': 'Old Lift'})),
          'a@a.com restored the exercise Old Lift');
      expect(describeAuditEntry(entry('exercise_deleted', {'name': 'Typo Lift'})),
          'a@a.com deleted the exercise Typo Lift');
    });

    test('duplicate and in_use errors show their detail', () {
      expect(adminErrorMessage(_serverError('in_use: Back Squat is used by 3 lifter(s). Retire it instead.')),
          'Back Squat is used by 3 lifter(s). Retire it instead.');
      expect(adminErrorMessage(_serverError('duplicate: the slug back_squat is already taken')),
          'The slug back_squat is already taken.');
    });
  });
}
