class AppConstants {
  static const double kMobileBreakpoint = 600.0;

  /// From this width the sidebar opens expanded by default; between
  /// [kMobileBreakpoint] and here it opens collapsed to a rail. Either way the
  /// user can toggle it, and the choice is remembered per side of this line.
  static const double kSidebarExpandedBreakpoint = 1024.0;

  /// Cap for the scaled-up in-progress workout timer: roughly the content width
  /// of a large phone (~430pt device minus the screen's 16pt horizontal
  /// padding), so the timer fills a phone edge-to-edge and stops growing on
  /// tablet/desktop.
  static const double kWorkoutTimerMaxWidth = 400.0;

  // Route paths
  /// The public privacy policy: web/privacy.html, published with the web app
  /// on GitHub Pages. The same URL is entered in App Store Connect and Play
  /// Console, so don't move it without updating both.
  static const String privacyPolicyUrl = 'https://nerdybeast.github.io/nomorex/privacy.html';

  static const String routeLanding = '/';
  static const String routeLogin = '/login';
  static const String routeProfile = '/profile';
  // Admin hub and its sections, reached from Profile. Admins only: the route
  // redirects everyone else (adminRouteRedirect).
  static const String routeAdmin = '/admin';
  static const String routeAdminUsers = '/admin/users';
  static const String routeAdminAiImports = '/admin/ai-imports';
  static const String routeAdminAuditLog = '/admin/audit-log';
  // AI import: choose and upload files. Linked from the Workouts and Programs
  // app bars (AiImportButton).
  static const String routeAiImport = '/ai-import';
  // Review one finished import job.
  static String routeAiImportReview(String jobId) => '/ai-import/review/$jobId';
  static const String routeShell = '/shell';
  static const String routeHome = '/shell/home';
  static const String routePrs = '/shell/prs';
  static const String routeAddPr = '/prs/add';
  static String routeAddPrForExercise(
    String exerciseId, {
    double? weightKg,
    int? reps,
  }) {
    final buffer = StringBuffer('$routeAddPr?exerciseId=$exerciseId');
    if (weightKg != null) buffer.write('&weightKg=$weightKg');
    if (reps != null) buffer.write('&reps=$reps');
    return buffer.toString();
  }
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
  static String routeCommunityProgramDetail(String id) => '/community/programs/$id';

  static const String routePrograms = '/shell/programs';
  // new: /programs/new ; detail: /programs/:id ; edit: /programs/:id/edit
  // day preview: /programs/:id/days/:dayId ; running instance: /program-instances/:id
  static const String routeProgramNew = '/programs/new';
  static const String routeProgramHistory = '/programs/history';
  static String routeProgramDetail(String id) => '/programs/$id';
  static String routeProgramEdit(String id) => '/programs/$id/edit';
  // The phone editor's week and day levels (#126). Desktop edits on one page.
  static String routeProgramEditWeek(String programId, String weekId) =>
      '/programs/$programId/edit/weeks/$weekId';
  static String routeProgramEditDay(String programId, String dayId) =>
      '/programs/$programId/edit/days/$dayId';
  static String routeProgramDayDetail(String programId, String dayId) =>
      '/programs/$programId/days/$dayId';
  static String routeProgramInstanceDetail(String id) => '/program-instances/$id';
}
