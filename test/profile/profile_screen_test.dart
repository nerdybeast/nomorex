import 'package:flutter/material.dart';
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

Widget _wrap(Profile profile, {void Function(String)? onSetUnitPreference}) => ProviderScope(
      overrides: [
        currentAuthUserProvider.overrideWithValue(_testUser),
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
}
