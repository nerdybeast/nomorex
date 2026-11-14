import 'package:go_router/go_router.dart';

import '../analytics.dart';

/// Logs a screen view each time [router] lands on a different route, named
/// by its pattern (`/workouts/:id`), so record IDs never reach analytics.
///
/// Listens to the router rather than adding a `NavigatorObserver`: the shell
/// tabs each have their own navigator, which a root observer doesn't see,
/// and go_router's pages have no names to report. Returns a function that
/// stops listening.
void Function() trackScreenViews(GoRouter router, AppAnalytics analytics) {
  String? last;
  void onChange() {
    final configuration = router.routerDelegate.currentConfiguration;
    if (configuration.isEmpty) return;
    final path = configuration.fullPath;
    if (path.isEmpty || path == last) return;
    last = path;
    analytics.logScreenView(path);
  }

  router.routerDelegate.addListener(onChange);
  return () => router.routerDelegate.removeListener(onChange);
}
