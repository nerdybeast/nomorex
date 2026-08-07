import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/dark_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/landing_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/shell/app_shell.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/personal_bests/screens/my_prs_screen.dart';
import 'features/personal_bests/screens/add_pr_screen.dart';
import 'features/workouts/screens/workouts_screen.dart';
import 'features/workouts/screens/new_workout_screen.dart';
import 'features/workouts/screens/edit_workout_screen.dart';
import 'features/workouts/screens/workout_detail_screen.dart';
import 'features/community/screens/community_screen.dart';
import 'features/community/screens/community_workout_detail_screen.dart';
import 'features/programs/screens/programs_screen.dart';
import 'features/programs/screens/new_program_screen.dart';
import 'features/programs/screens/program_edit_screen.dart';
import 'features/programs/screens/program_detail_screen.dart';

part 'app.g.dart';

class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, _) => notifyListeners());
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
  return GoRouter(
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
              path: AppConstants.routePrs,
              builder: (_, _) => const MyPrsScreen(),
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
              path: AppConstants.routeCommunity,
              builder: (_, _) => const CommunityScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppConstants.routePrograms,
              builder: (_, _) => const ProgramsScreen(),
            ),
          ]),
        ],
      ),
      GoRoute(
        path: AppConstants.routeAddPr,
        builder: (_, _) => const AddPrScreen(),
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
        path: '/workouts/:id',
        builder: (_, state) =>
            WorkoutDetailScreen(workoutId: state.pathParameters['id']!),
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
      GoRoute(
        path: '/programs/:id/edit',
        builder: (_, state) =>
            ProgramEditScreen(programId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/programs/:id',
        builder: (_, state) =>
            ProgramDetailScreen(programId: state.pathParameters['id']!),
      ),
    ],
  );
}

class NomorexApp extends ConsumerWidget {
  const NomorexApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'NoMoreX',
      theme: AppDarkTheme.sleekOrange(),
      routerConfig: router,
    );
  }
}
