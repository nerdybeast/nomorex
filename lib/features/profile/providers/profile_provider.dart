import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';
import '../../auth/providers/auth_provider.dart';

part 'profile_provider.g.dart';

@Riverpod(keepAlive: true)
class ProfileNotifier extends _$ProfileNotifier {
  @override
  Future<Profile?> build() async {
    // Rebuild whenever auth state changes (prevents cross-user data leaks)
    ref.watch(authStateProvider);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;

    final data = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (data == null) return null;
    return Profile.fromJson(data);
  }

  Future<void> setUnitPreference(String unit) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    await Supabase.instance.client
        .from('profiles')
        .upsert({'id': userId, 'unit_preference': unit});

    ref.invalidateSelf();
    await future;
  }

  /// Sets the name shown as the author on this user's public workouts and
  /// programs. An empty name clears it, putting them back on the anonymous
  /// fallback rather than storing a blank string.
  Future<void> setDisplayName(String name) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final trimmed = name.trim();

    await Supabase.instance.client
        .from('profiles')
        .upsert({'id': userId, 'display_name': trimmed.isEmpty ? null : trimmed});

    // No cross-provider invalidation needed: both community lists exclude the
    // viewer's own rows, so nothing on screen renders this user's own name.
    ref.invalidateSelf();
    await future;
  }
}

/// Derived provider — returns the user's unit preference ('kg', 'lbs', or
/// 'both'), defaulting to 'both'.
@Riverpod(keepAlive: true)
String unitPreference(Ref ref) {
  return ref.watch(profileProvider).asData?.value?.unitPreference ?? 'both';
}

/// The signed-in user's own display name, or null if they haven't set one.
@Riverpod(keepAlive: true)
String? displayName(Ref ref) {
  return ref.watch(profileProvider).asData?.value?.displayName;
}
