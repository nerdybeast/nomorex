import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/app_roles.dart';

part 'current_roles_provider.g.dart';

/// The signed-in user's roles (`user_roles`, which RLS limits to their own
/// rows). Empty when signed out.
///
/// Only decides what the app shows: every admin function checks the role
/// again on the server.
@Riverpod(keepAlive: true)
Future<Set<String>> currentUserRoles(Ref ref) async {
  final user = ref.watch(currentAuthUserProvider);
  if (user == null) return const {};
  final rows = await Supabase.instance.client.from('user_roles').select('role').eq('user_id', user.id);
  return {for (final row in rows) row['role'] as String};
}

/// Whether the signed-in user is an admin. False while the roles load or if
/// they couldn't be read.
@Riverpod(keepAlive: true)
bool isAdmin(Ref ref) {
  return ref.watch(currentUserRolesProvider).value?.contains(AppRoles.admin) ?? false;
}
