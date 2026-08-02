class AppConstants {
  static const double kMobileBreakpoint = 600.0;

  // Route paths
  static const String routeLanding = '/';
  static const String routeLogin = '/login';
  static const String routeShell = '/shell';
  static const String routeHome = '/shell/home';
  static const String routePrs = '/shell/prs';
  static const String routeAddPr = '/prs/add';

  static const String routeWorkouts = '/shell/workouts';
  // detail: /workouts/:id ; edit: /workouts/:id/edit
  static String routeWorkoutDetail(String id) => '/workouts/$id';
  static String routeWorkoutEdit(String id) => '/workouts/$id/edit';

  static const String routeCommunity = '/shell/community';
  static String routeCommunityWorkoutDetail(String id) => '/community/$id';
}
