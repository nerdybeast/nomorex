import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'auth_provider.g.dart';

@Riverpod(keepAlive: true)
Stream<AuthState> authState(Ref ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
}

/// The signed-in Supabase auth user, or null when signed out. Wraps
/// [authStateProvider] so it's overridable in widget tests instead of
/// reading `Supabase.instance.client.auth.currentUser` directly.
@Riverpod(keepAlive: true)
User? currentAuthUser(Ref ref) {
  ref.watch(authStateProvider);
  return Supabase.instance.client.auth.currentUser;
}

/// Keeps Sentry's user context in sync with [currentAuthUserProvider] so
/// error reports are attributed to whoever was signed in when they occurred.
/// Watched once from [NomorexApp] to run for the lifetime of the app.
@Riverpod(keepAlive: true)
void sentryUserSync(Ref ref) {
  ref.listen(currentAuthUserProvider, (previous, user) {
    Sentry.configureScope(
      (scope) => scope.setUser(
        user == null ? null : SentryUser(id: user.id, email: user.email),
      ),
    );
  }, fireImmediately: true);
}

@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier {
  @override
  void build() {}

  Future<void> signIn(String email, String password) async {
    await Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
  }
}
