class AppConstants {
  static const double kMobileBreakpoint = 600.0;

  // Route paths
  static const String routeLanding = '/';
  static const String routeLogin = '/login';
  static const String routeProfile = '/profile';
  static const String routeShell = '/shell';
  static const String routeHome = '/shell/home';
  static const String routePrs = '/shell/prs';
  static const String routeAddPr = '/prs/add';
  static String routeAddPrForExercise(String exerciseId) =>
      '$routeAddPr?exerciseId=$exerciseId';
  static String routePrHistory(String exerciseId) => '/prs/$exerciseId/history';

  static const String routeWorkouts = '/shell/workouts';
  // new: /workouts/new ; detail: /workouts/:id ; edit: /workouts/:id/edit
  // history (all workouts, or filtered by ?groupId=): /workouts/history
  static const String routeWorkoutNew = '/workouts/new';
  static String routeWorkoutDetail(String id) => '/workouts/$id';
  static String routeWorkoutEdit(String id) => '/workouts/$id/edit';
  static String routeWorkoutFinish(String id) => '/workouts/$id/finish';
  static const String routeWorkoutHistory = '/workouts/history';
  static String routeWorkoutHistoryFiltered(String groupId) =>
      '$routeWorkoutHistory?groupId=$groupId';

  static const String routeCommunity = '/shell/community';
  static String routeCommunityWorkoutDetail(String id) => '/community/$id';

  static const String routePrograms = '/shell/programs';
  // new: /programs/new ; detail: /programs/:id ; edit: /programs/:id/edit
  // day preview: /programs/:id/days/:dayId ; running instance: /program-instances/:id
  static const String routeProgramNew = '/programs/new';
  static String routeProgramDetail(String id) => '/programs/$id';
  static String routeProgramEdit(String id) => '/programs/$id/edit';
  static String routeProgramDayDetail(String programId, String dayId) =>
      '/programs/$programId/days/$dayId';
  static String routeProgramInstanceDetail(String id) => '/program-instances/$id';
}
