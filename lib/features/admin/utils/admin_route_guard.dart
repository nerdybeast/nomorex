import '../../../core/constants/app_constants.dart';
import '../models/app_roles.dart';

/// The redirect for everything under [AppConstants.routeAdmin]: anyone who
/// isn't an admin, or whose roles can't be read, goes to Profile instead.
///
/// Takes the roles as a future so it waits for them to load. Reading the
/// provider's current value would see "not loaded yet" as "not an admin".
Future<String?> adminRouteRedirect(Future<Set<String>> Function() readRoles) async {
  try {
    final roles = await readRoles();
    return roles.contains(AppRoles.admin) ? null : AppConstants.routeProfile;
  } catch (_) {
    return AppConstants.routeProfile;
  }
}
