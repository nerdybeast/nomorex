import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/auth/providers/auth_provider.dart';
import 'package:nomorex/features/profile/models/profile.dart';
import 'package:nomorex/features/profile/providers/profile_provider.dart';
import 'package:nomorex/features/profile/screens/profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _testUser = User(
  id: 'u1',
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  email: 'lifter@example.com',
  createdAt: '2026-01-15T00:00:00Z',
);

const _longUuid = 'efc6e9c2-6585-42a1-a5c2-fcac5c6c1234';

const _longIdUser = User(
  id: _longUuid,
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  email: 'lifter@example.com',
  createdAt: '2026-01-15T00:00:00Z',
);

class _RecordingAuthNotifier extends AuthNotifier {
  _RecordingAuthNotifier(this.onSignOut);
  final VoidCallback onSignOut;

  @override
  Future<void> signOut() async => onSignOut();
}

class _TestProfileNotifier extends ProfileNotifier {
  _TestProfileNotifier(this._profile, {this.onSetUnitPreference, this.onSetDisplayName});
  Profile? _profile;
  final void Function(String)? onSetUnitPreference;
  final void Function(String)? onSetDisplayName;

  @override
  Future<Profile?> build() async => _profile;

  @override
  Future<void> setUnitPreference(String unit) async {
    onSetUnitPreference?.call(unit);
    _profile = _profile!.copyWith(unitPreference: unit);
    ref.invalidateSelf();
    await future;
  }

  @override
  Future<void> setDisplayName(String name) async {
    onSetDisplayName?.call(name);
    ref.invalidateSelf();
    await future;
  }
}

Widget _wrap(
  Profile profile, {
  void Function(String)? onSetUnitPreference,
  void Function(String)? onSetDisplayName,
  User user = _testUser,
  VoidCallback? onSignOut,
}) =>
    ProviderScope(
      overrides: [
        currentAuthUserProvider.overrideWithValue(user),
        profileProvider.overrideWith(
          () => _TestProfileNotifier(
            profile,
            onSetUnitPreference: onSetUnitPreference,
            onSetDisplayName: onSetDisplayName,
          ),
        ),
        if (onSignOut != null) authProvider.overrideWith(() => _RecordingAuthNotifier(onSignOut)),
      ],
      child: const MaterialApp(home: ProfileScreen()),
    );

void main() {
  testWidgets('shows the user id, email, and member-since date', (tester) async {
    await tester.pumpWidget(_wrap(const Profile(id: 'u1', unitPreference: 'both')));
    await tester.pumpAndSettle();

    expect(find.text('u1'), findsOneWidget);
    expect(find.text('lifter@example.com'), findsOneWidget);
    expect(find.text('Jan 15, 2026'), findsOneWidget);
  });

  testWidgets('preselects the segmented button to the current preference', (tester) async {
    await tester.pumpWidget(_wrap(const Profile(id: 'u1', unitPreference: 'lbs')));
    await tester.pumpAndSettle();

    final button = tester.widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>));
    expect(button.selected, {'lbs'});
  });

  testWidgets('selecting a unit calls setUnitPreference', (tester) async {
    String? captured;

    await tester.pumpWidget(
      _wrap(
        const Profile(id: 'u1', unitPreference: 'both'),
        onSetUnitPreference: (u) => captured = u,
      ),
    );
    await tester.pumpAndSettle();

    // The display-name section sits above PREFERENCES, so the unit toggle can
    // be below the fold in the default test viewport.
    await tester.ensureVisible(find.text('kg'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('kg'));
    await tester.pumpAndSettle();

    expect(captured, 'kg');
  });

  testWidgets('seeds the display-name field from the profile', (tester) async {
    await tester.pumpWidget(
      _wrap(const Profile(id: 'u1', unitPreference: 'both', displayName: 'BeastModeB')),
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byKey(const Key('profile_display_name')));
    expect(field.controller?.text, 'BeastModeB');
  });

  testWidgets('leaves the display-name field empty when none is set', (tester) async {
    await tester.pumpWidget(_wrap(const Profile(id: 'u1', unitPreference: 'both')));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byKey(const Key('profile_display_name')));
    expect(field.controller?.text, isEmpty);
  });

  testWidgets('saving the display name calls setDisplayName', (tester) async {
    String? captured;

    await tester.pumpWidget(
      _wrap(
        const Profile(id: 'u1', unitPreference: 'both'),
        onSetDisplayName: (n) => captured = n,
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('profile_display_name')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('profile_display_name')), 'BeastModeB');

    await tester.ensureVisible(find.byKey(const Key('profile_display_name_save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile_display_name_save')));
    await tester.pumpAndSettle();

    expect(captured, 'BeastModeB');
  });

  testWidgets('shows the full user id without truncation', (tester) async {
    await tester.pumpWidget(
      _wrap(const Profile(id: _longUuid, unitPreference: 'both'), user: _longIdUser),
    );
    await tester.pumpAndSettle();

    expect(find.text(_longUuid), findsOneWidget);
    expect(find.byType(SelectableText), findsWidgets);
    // Scoped to the id's own widget rather than every Text on screen: the
    // display-name input's hint renders with ellipsis overflow by default,
    // which has nothing to do with truncating the id.
    final idField = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .firstWhere((s) => s.data == _longUuid);
    expect(idField.maxLines, isNull);
  });

  testWidgets('copy button copies the user id to the clipboard', (tester) async {
    final copiedTexts = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform,
        (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedTexts.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
    addTearDown(() =>
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(
      _wrap(const Profile(id: _longUuid, unitPreference: 'both'), user: _longIdUser),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.copy_rounded));
    await tester.pump();

    expect(copiedTexts, [_longUuid]);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('tapping the sign-out icon shows a confirmation dialog', (tester) async {
    await tester.pumpWidget(_wrap(const Profile(id: 'u1', unitPreference: 'both')));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();

    expect(find.text('Log Out'), findsNWidgets(2)); // dialog title + confirm button
    expect(find.text('Are you sure you want to log out?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('cancelling the confirmation dialog does not sign out', (tester) async {
    var signedOut = false;
    await tester.pumpWidget(
      _wrap(const Profile(id: 'u1', unitPreference: 'both'), onSignOut: () => signedOut = true),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(signedOut, isFalse);
    expect(find.text('Are you sure you want to log out?'), findsNothing);
  });

  testWidgets('confirming Log Out signs the user out', (tester) async {
    var signedOut = false;
    await tester.pumpWidget(
      _wrap(const Profile(id: 'u1', unitPreference: 'both'), onSignOut: () => signedOut = true),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Log Out'));
    await tester.pumpAndSettle();

    expect(signedOut, isTrue);
  });
}
