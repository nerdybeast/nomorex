import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';

part 'profile_provider.g.dart';

@Riverpod(keepAlive: true)
class ProfileNotifier extends _$ProfileNotifier {
  @override
  Future<Profile?> build() async {
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
        .update({'unit_preference': unit})
        .eq('id', userId);

    ref.invalidateSelf();
    await future;
  }
}

/// Derived provider — returns the user's unit preference, defaulting to 'kg'.
@Riverpod(keepAlive: true)
String unitPreference(Ref ref) {
  return ref.watch(profileProvider).asData?.value?.unitPreference ?? 'kg';
}
