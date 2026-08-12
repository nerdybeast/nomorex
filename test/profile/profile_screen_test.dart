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

class _TestProfileNotifier extends ProfileNotifier {
  _TestProfileNotifier(this._profile, {this.onSetUnitPreference});
  Profile? _profile;
  final void Function(String)? onSetUnitPreference;

  @override
  Future<Profile?> build() async => _profile;

  @override
  Future<void> setUnitPreference(String unit) async {
    onSetUnitPreference?.call(unit);
    _profile = Profile(id: _profile!.id, unitPreference: unit);
    ref.invalidateSelf();
    await future;
  }
}

Widget _wrap(
  Profile profile, {
  void Function(String)? onSetUnitPreference,
  User user = _testUser,
}) =>
    ProviderScope(
      overrides: [
        currentAuthUserProvider.overrideWithValue(user),
        profileProvider.overrideWith(
          () => _TestProfileNotifier(profile, onSetUnitPreference: onSetUnitPreference),
        ),
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

    await tester.tap(find.text('kg'));
    await tester.pumpAndSettle();

    expect(captured, 'kg');
  });

  testWidgets('shows the full user id without truncation', (tester) async {
    await tester.pumpWidget(
      _wrap(const Profile(id: _longUuid, unitPreference: 'both'), user: _longIdUser),
    );
    await tester.pumpAndSettle();

    expect(find.text(_longUuid), findsOneWidget);
    expect(find.byType(SelectableText), findsWidgets);
    expect(
      tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => t.overflow == TextOverflow.ellipsis),
      isEmpty,
    );
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
}
