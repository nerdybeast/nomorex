import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/ai/screens/ai_import_screen.dart';
import 'features/ai/screens/ai_import_review_screen.dart';
import 'features/ai/widgets/ai_import_job_alerts.dart';
import 'features/analytics/providers/analytics_provider.dart';
import 'features/analytics/utils/screen_tracking.dart';
import 'features/admin/providers/current_roles_provider.dart';
import 'features/admin/screens/admin_ai_imports_screen.dart';
import 'features/admin/screens/admin_audit_log_screen.dart';
import 'features/admin/screens/admin_users_screen.dart';
import 'features/admin/screens/admin_screen.dart';
import 'features/admin/utils/admin_route_guard.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/landing_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/shell/app_frame.dart';
import 'features/shell/app_shell.dart';
import 'shared/widgets/haptic_tap_scope.dart';
import 'shared/widgets/keyboard_dismiss_scope.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/personal_bests/screens/my_prs_screen.dart';
import 'features/personal_bests/screens/add_pr_screen.dart';
import 'features/personal_bests/screens/pr_history_screen.dart';
import 'features/workouts/screens/workouts_screen.dart';
import 'features/workouts/screens/new_workout_screen.dart';
import 'features/workouts/screens/edit_workout_screen.dart';
import 'features/workouts/screens/workout_detail_screen.dart';
import 'features/workouts/screens/finish_workout_screen.dart';
import 'features/workouts/screens/workout_history_screen.dart';
import 'features/community/screens/community_screen.dart';
import 'features/community/screens/community_program_detail_screen.dart';
import 'features/community/screens/community_workout_detail_screen.dart';
import 'features/programs/screens/programs_screen.dart';
import 'features/programs/screens/new_program_screen.dart';
import 'features/programs/screens/program_history_screen.dart';
import 'features/programs/screens/edit/program_day_edit_screen.dart';
import 'features/programs/screens/edit/program_edit_entry.dart';
import 'features/programs/screens/edit/program_week_edit_screen.dart';
import 'features/programs/screens/program_detail_screen.dart';
import 'features/programs/screens/program_day_detail_screen.dart';
import 'features/programs/screens/program_instance_detail_screen.dart';

part 'app.g.dart';

class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, _) => notifyListeners());
    // Re-runs the /admin redirect when roles change, so someone whose admin
    // role is removed is moved off the admin screens.
    _ref.listen(currentUserRolesProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isAuthenticated = session != null;
    final loc = state.matchedLocation;
    final isPublicRoute = loc == AppConstants.routeLanding ||
        loc == AppConstants.routeLogin;

    if (!isAuthenticated && !isPublicRoute) return AppConstants.routeLanding;
    if (isAuthenticated && isPublicRoute) return AppConstants.routeHome;
    return null;
  }
}

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final notifier = RouterNotifier(ref);
  final router = GoRouter(
    // Records screen changes as Sentry breadcrumbs.
    observers: [SentryNavigatorObserver()],
    refreshListenable: notifier,
    redirect: notifier.redirect,
    initialLocation: AppConstants.routeLanding,
    routes: [
      GoRoute(
        path: AppConstants.routeLanding,
        builder: (_, _) => const LandingScreen(),
      ),
      GoRoute(
        path: AppConstants.routeLogin,
        builder: (_, _) => const LoginScreen(),
      ),
      // Every signed-in page. On wide layouts AppFrame keeps the sidebar
      // beside whichever of them is showing; on a phone it adds nothing.
      ShellRoute(
        builder: (context, state, child) => AppFrame(location: state.uri.path, child: child),
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) => AppShell(shell: shell),
            branches: [
              StatefulShellBranch(routes: [
                GoRoute(
                  path: AppConstants.routeHome,
                  builder: (_, _) => const DashboardScreen(),
                ),
              ]),
              StatefulShellBranch(routes: [
                GoRoute(
                  path: AppConstants.routePrograms,
                  builder: (_, _) => const ProgramsScreen(),
                ),
              ]),
              StatefulShellBranch(routes: [
                GoRoute(
                  path: AppConstants.routeWorkouts,
                  builder: (_, _) => const WorkoutsScreen(),
                ),
              ]),
              StatefulShellBranch(routes: [
                GoRoute(
                  path: AppConstants.routePrs,
                  builder: (_, _) => const MyPrsScreen(),
                ),
              ]),
              StatefulShellBranch(routes: [
                GoRoute(
                  path: AppConstants.routeCommunity,
                  builder: (_, _) => const CommunityScreen(),
                ),
              ]),
            ],
          ),
          GoRoute(
            path: AppConstants.routeProfile,
            builder: (_, _) => const ProfileScreen(),
          ),
          GoRoute(
            path: AppConstants.routeAdmin,
            // Runs for the child routes too. The server checks the role again on
            // every admin call; this only keeps non-admins off the screens.
            redirect: (_, _) => adminRouteRedirect(() => ref.read(currentUserRolesProvider.future)),
            builder: (_, _) => const AdminScreen(),
            routes: [
              GoRoute(
                path: 'users',
                builder: (_, _) => const AdminUsersScreen(),
              ),
              GoRoute(
                path: 'ai-imports',
                builder: (_, _) => const AdminAiImportsScreen(),
              ),
              GoRoute(
                path: 'audit-log',
                builder: (_, _) => const AdminAuditLogScreen(),
              ),
            ],
          ),
          GoRoute(
            path: AppConstants.routeAiImport,
            builder: (_, _) => const AiImportScreen(),
          ),
          GoRoute(
            path: '/ai-import/review/:jobId',
            builder: (_, state) => AiImportReviewScreen(jobId: state.pathParameters['jobId']!),
          ),
          GoRoute(
            path: AppConstants.routeAddPr,
            builder: (_, state) => AddPrScreen(
              exerciseId: state.uri.queryParameters['exerciseId'],
              initialWeightKg: double.tryParse(state.uri.queryParameters['weightKg'] ?? ''),
              initialReps: int.tryParse(state.uri.queryParameters['reps'] ?? ''),
            ),
          ),
          GoRoute(
            path: '/prs/:exerciseId/history',
            builder: (_, state) =>
                PrHistoryScreen(exerciseId: state.pathParameters['exerciseId']!),
          ),
          GoRoute(
            path: AppConstants.routeWorkoutNew,
            builder: (_, _) => const NewWorkoutScreen(),
          ),
          GoRoute(
            path: '/workouts/:id/edit',
            builder: (_, state) =>
                EditWorkoutScreen(workoutId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/workouts/:id/finish',
            builder: (_, state) =>
                FinishWorkoutScreen(workoutId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: AppConstants.routeWorkoutHistory,
            builder: (_, state) => WorkoutHistoryScreen(
              initialGroupId: state.uri.queryParameters['groupId'],
            ),
          ),
          GoRoute(
            path: '/workouts/:id',
            builder: (_, state) =>
                WorkoutDetailScreen(workoutId: state.pathParameters['id']!),
          ),
          // Declared ahead of '/community/:id' so the static "programs" segment is
          // never mistaken for a workout id.
          GoRoute(
            path: '/community/programs/:id',
            builder: (_, state) =>
                CommunityProgramDetailScreen(programId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/community/:id',
            builder: (_, state) =>
                CommunityWorkoutDetailScreen(workoutId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: AppConstants.routeProgramNew,
            builder: (_, _) => const NewProgramScreen(),
          ),
          // Static segment, declared ahead of '/programs/:id'.
          GoRoute(
            path: AppConstants.routeProgramHistory,
            builder: (_, _) => const ProgramHistoryScreen(),
          ),
          GoRoute(
            path: '/programs/:id/edit',
            builder: (_, state) =>
                ProgramEditEntry(programId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/programs/:id/edit/weeks/:weekId',
            builder: (_, state) => ProgramWeekEditScreen(
              programId: state.pathParameters['id']!,
              weekId: state.pathParameters['weekId']!,
            ),
          ),
          GoRoute(
            path: '/programs/:id/edit/days/:dayId',
            builder: (_, state) => ProgramDayEditScreen(
              programId: state.pathParameters['id']!,
              dayId: state.pathParameters['dayId']!,
            ),
          ),
          GoRoute(
            path: '/programs/:programId/days/:dayId',
            builder: (_, state) => ProgramDayDetailScreen(
              programId: state.pathParameters['programId']!,
              dayId: state.pathParameters['dayId']!,
            ),
          ),
          GoRoute(
            path: '/programs/:id',
            builder: (_, state) =>
                ProgramDetailScreen(programId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/program-instances/:id',
            builder: (_, state) =>
                ProgramInstanceDetailScreen(instanceId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(trackScreenViews(router, ref.read(analyticsProvider)));
  return router;
}

class NomorexApp extends ConsumerWidget {
  const NomorexApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(sentryUserSyncProvider);
    // Loads the user's analytics choice at startup and applies it. Listened
    // to rather than watched, so toggling it doesn't rebuild the app.
    ref.listen(analyticsConsentProvider, (_, _) {});
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'NoMoreX',
      // Follows the device setting; the design system defines both themes.
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
      builder: (context, child) => AiImportJobAlerts(
        navigate: (location) => router.push(location),
        child: HapticTapScope(child: KeyboardDismissScope(child: child!)),
      ),
    );
  }
}
